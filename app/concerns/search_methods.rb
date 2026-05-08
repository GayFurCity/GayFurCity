# frozen_string_literal: true

module SearchMethods
  extend(ActiveSupport::Concern)

  module ClassMethods
    include(AttributeMatchers)

    def paginate(page, options = {})
      extending(GayFurCity::Paginator::ActiveRecordExtension).paginate(page, options)
    end

    def paginate_posts(page, options = {})
      options[:user] ||= User.anonymous
      extending(GayFurCity::Paginator::ActiveRecordExtension).paginate_posts(page, options)
    end

    def qualified_column_for(attr)
      "#{table_name}.#{column_for_attribute(attr).name}"
    end

    def where_like(attr, value)
      where("#{qualified_column_for(attr)} LIKE ? ESCAPE E'\\\\'", value.to_escaped_for_sql_like)
    end

    def where_ilike(attr, value)
      where("lower(#{qualified_column_for(attr)}) LIKE ? ESCAPE E'\\\\'", value.downcase.to_escaped_for_sql_like)
    end

    def join_as(association, alias_name, type = Arel::Nodes::InnerJoin, base_model = self)
      case association
      when Symbol, String
        reflection = base_model.reflect_on_association(association)
        raise(ArgumentError, "no such association: #{association}") unless reflection

        base_table = base_model.arel_table
        alias_table = reflection.klass.arel_table.alias(alias_name.to_s)

        join_node = base_table.join(alias_table, type)
                              .on(alias_table[reflection.association_primary_key]
                                    .eq(base_table[reflection.foreign_key]))
                              .join_sources

        joins(join_node)

      when Hash
        outer, inner = association.first
        outer_reflection = base_model.reflect_on_association(outer)
        raise(ArgumentError, "no such association: #{outer}") unless outer_reflection

        base_table = base_model.arel_table
        outer_alias = "#{alias_name}_#{outer}"
        outer_alias_table = outer_reflection.klass.arel_table.alias(outer_alias)

        outer_join = base_table.join(outer_alias_table, type)
                               .on(outer_alias_table[outer_reflection.association_primary_key]
                                     .eq(base_table[outer_reflection.foreign_key]))
                               .join_sources

        # Apply outer join first, then recurse deeper
        relation = joins(outer_join)
        relation.join_as(inner, alias_name, type, outer_reflection.klass)

      else
        raise(ArgumentError, "association must be a Symbol, String, or Hash")
      end
    end

    def get_column(attribute)
      QueryHelper.get_column(attribute, table_name)
    end

    def attribute_exact_matches(attribute, value, **_options)
      return all if value.blank?

      column = qualified_column_for(attribute)
      where("#{column} = ?", value)
    end

    def attributes_match(**conditions, &)
      options = conditions.extract!(:convert_to_wildcard)
      return all if conditions.all? { |(_k, v)| v.nil? }

      QueryHelper.parse_conditions(conditions, self).map do |(table_name, column_name), value|
        attribute_matches("#{table_name}.#{column_name}", value, **options, &)
      end.reduce(&:and)
    end

    def attribute_matches(attribute, value, **, &)
      return all if value.nil?
      column = get_column(attribute)
      case column.sql_type_metadata.type
      when :boolean
        boolean_attribute_matches(attribute, value, **, &)
      when :integer, :datetime
        numeric_attribute_matches(attribute, value, **, &)
      when :string, :text
        text_attribute_matches(attribute, value, **, &)
      when :inet
        ip_attribute_matches(attribute, value, **, &)
      else
        raise(ArgumentError, "unhandled attribute type: #{column.sql_type_metadata.type}")
      end
    end

    def not_attribute_matches(attribute, value, **, &)
      positive = attribute_matches(attribute, value, **, &)
      added_predicates = positive.where_clause - all.where_clause
      where.not(added_predicates.ast)
    end

    def user_name_matches(attribute, value)
      return all if value.blank?
      name = attribute
      name = name.values.first while name.is_a?(Hash)
      join_as(attribute, "#{name}_users").where("#{name}_users.name": value)
    end

    def if(condition, truthy_value, nil_value = nil)
      ConditionalRelation.new(all, condition.to_s.truthy?, truthy_value, nil_value)
    end

    def order_with(orders, value, direction: :desc, secondary: { id: direction })
      return default_order if value.nil?
      value = value.to_sym
      if orders.is_a?(Array)
        orders.map!(&:to_s)
        orders.unshift("id") unless orders.include?("id")
        orders.unshift("created_at") if orders.exclude?("created_at") && attribute_names.include?("created_at")
        orders.unshift("updated_at") if orders.exclude?("updated_at") && attribute_names.include?("updated_at")
      elsif orders.is_a?(Hash)
        orders.transform_keys!(&:to_s)
        orders["id"] = { id: direction } unless orders.key?("id")
        orders["created_at"] = { created_at: direction } if !orders.key?("created_at") && attribute_names.include?("created_at")
        orders["updated_at"] = { updated_at: direction } if !orders.key?("updated_at") && attribute_names.include?("updated_at")
      end
      orders = order_to_array(orders.dup, direction)

      orders.each do |key, list|
        next if list.is_a?(Proc) || key.to_s.match?(/_(asc|desc)$/) || list.length != 1
        asc = orders.any? { |o| o[0] == :"#{key}_asc" }
        desc = orders.any? { |o| o[0] == :"#{key}_desc" }
        Rails.logger.debug { "#{key},#{asc},#{desc}" }
        orders.push([:"#{key}_asc", [[list[0][0], list[0][1], :asc]]]) unless asc
        orders.push([:"#{key}_desc", [[list[0][0], list[0][1], :desc]]]) unless desc
      end
      orders.sort! { |a, b| a.first.to_s <=> b.first.to_s }
      orders = order_array_to_hash(orders)

      return default_order unless orders.key?(value)

      v = orders[value]
      if v.is_a?(Proc)
        q = v.call
      else
        q = order(v)
        if secondary.present?
          k = secondary.keys.first.to_sym
          q = q.order(secondary) unless %I[#{k} #{k}_asc #{k}_desc].include?(value)
        end
      end
      q
    end

    def order_array_to_hash(arr)
      arr.to_h do |o|
        next o if o[1].is_a?(Proc)
        [
          o[0],
          o[1].to_h do |t|
            [:"#{t[0]}.#{t[1]}", t[2]]
          end,
        ]
      end
    end

    def order_to_array(arg, dir)
      if arg.is_a?(Array)
        arg.map do |name|
          if name.include?(".")
            table, column = name.split(".", 2)
          else
            table = table_name
            column = name
          end
          [name.to_sym, [[table.to_sym, column.to_sym, dir]]]
        end
      else
        arg.each_pair.map do |name, hash|
          next [name.to_sym, hash] unless hash.is_a?(Hash)
          list = hash.keys.map do |key|
            if key.to_s.include?(".")
              table, column = key.to_s.split(".", 2)
            else
              table = table_name
              column = key
            end
            [table.to_sym, column.to_sym, hash[key]]
          end
          [name.to_sym, list]
        end
      end
    end

    def basic_order(value, **)
      order_with([], value, **)
    end

    def arel_case(column)
      Arel::Nodes::Case.new(arel(column))
    end

    def apply_order(params)
      basic_order(params[:order])
    end

    def case_order(column, values)
      other = values.find_index(&:nil?) || values.size
      order = arel_case(column)
      values.each_with_index do |value, index|
        next if value.nil?
        order = order.when(value).then(index)
      end
      order.else(other)
    end

    def arel(column)
      arel_table[column.to_sym]
    end

    def with_resolved_user_ids(query_field, params, &)
      user_name_key = (query_field.is_a?(Symbol) ? "#{query_field}_name" : query_field[0]).to_sym
      user_id_key = (query_field.is_a?(Symbol) ? "#{query_field}_id" : query_field[1]).to_sym

      if params[user_name_key].present?
        user_ids = [User.name_to_id(params[user_name_key]) || 0]
      end
      if params[user_id_key].present?
        user_ids = params[user_id_key].to_s.split(",").first(100).map(&:to_i)
      end

      yield(user_ids) if user_ids
    end

    # Searches for a user both by id and name.
    # Accepts a block to modify the query when one of the params is present and yields the ids.
    def where_user(db_field, query_field, params)
      q = all
      with_resolved_user_ids(query_field, params) do |user_ids|
        q = yield(q, user_ids) if block_given?
        q = q.where(to_where_hash(db_field, user_ids))
      end
      q
    end

    def default_order
      order(id: :desc)
    end

    def query_dsl
      QueryDSL.new(self)
    end

    def old_search(params, user, visible: false)
      params ||= {}
      params.transform_keys!(&:to_sym)

      unless (params.is_a?(ActionController::Parameters) || params.is_a?(Hash)) && user.is_a?(UserLike)
        raise(ArgumentError, "search expects (HashLike, UserLike), got (#{params.class}, #{user.class})")
      end

      q = all
      q = q.visible(user) if visible
      q = q.attributes_match(id: params[:id])
      q = q.attributes_match(created_at: params[:created_at]) if attribute_names.include?("created_at")
      q = q.attributes_match(updated_at: params[:updated_at]) if attribute_names.include?("updated_at")

      q
    end

    def search(params, user, visible: true)
      params ||= {}
      params.transform_keys!(&:to_sym)

      unless (params.is_a?(ActionController::Parameters) || params.is_a?(Hash)) && user.is_a?(UserLike)
        raise(ArgumentError, "search expects (HashLike, UserLike), got (#{params.class}, #{user.class})")
      end

      q = all
      q = q.visible(user) if visible
      QueryBuilder.new(query_dsl.build, self, q, user)
                  .search(params)
                  .apply_order(params)
    end

    private

    # to_where_hash(:a, 1) => { a: 1 }
    # to_where_hash(a: :b, 1) => { a: { b: 1 } }
    def to_where_hash(field, value)
      if field.is_a?(Symbol)
        { field => value }
      elsif field.is_a?(Hash) && field.size == 1 && field.values.first.is_a?(Symbol)
        { field.keys.first => { field.values.first => value } }
      else
        raise(StandardError, "Unsupported field: #{field.class} => #{field}")
      end
    end
  end
end

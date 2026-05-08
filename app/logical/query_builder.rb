# frozen_string_literal: true

class QueryBuilder
  attr_reader(:dsl, :klass, :relation, :user, :q)

  # [param, db_field, type]
  def initialize(dsl, klass, relation, user)
    dsl ||= []
    @dsl = dsl
    @klass = klass
    @relation = relation
    @user = user
    @q = relation
  end

  def process_dsl(dsl, params)
    dsl[:fields].each do |param, field, type = nil, block = nil, options = {}|
      value = params[param]
      multi = options.fetch(:multi, nil) || false
      like = options.fetch(:like, nil) || false
      ilike = options.fetch(:ilike, nil) || false
      normalize = options.fetch(:normalize, nil) || ->(value) { value }
      next if value.nil?
      value = normalize.call(value)
      @q = block.call(q) if block
      if type.is_a?(Proc)
        args = [q, value, user, params]
        @q = type.call(*args.first(type.arity))
        next
      end
      field ||= param
      if like
        @q = q.where.like(field => value)
        next
      elsif ilike
        @q = q.where.ilike(field => value)
        next
      end
      type ||= QueryHelper.get_column(field, klass.table_name).sql_type_metadata.type
      case type
      when :boolean
        @q = q.boolean_attribute_matches(field, value)
      when :integer
        # multiple comma separated values are implicitly supported
        # trimming them seems unneeded
        # value = value[0.. value.index(",") - 1] unless multi
        @q = q.numeric_attribute_matches(field, value)
      when :datetime
        @q = q.datetime_attribute_matches(field, value)
      when :text, :string
        value = value.split(",").first(Config.instance.max_multi_count) if multi # explicitly supports arrays
        @q = q.text_attribute_matches(field, value)
      when :inet
        @q = q.ip_attribute_matches(field, value)
      when :present
        @q = q.attribute_present(field, value)
      else
        raise(ArgumentError, "Unknown type: #{type} for field: #{field}")
      end
    end

    dsl[:associations].each do |attribute, klass, nested_dsl, join|
      next if params[attribute].nil?
      @q = q.joins(join)
      nested_relation = klass.all
      nested_builder = QueryBuilder.new(nested_dsl, klass, nested_relation, user)
      nested_relation = nested_builder.search(params[attribute])
      @q = q.merge(nested_relation)
    end
  end

  def search(params = {})
    params.transform_keys!(&:to_sym)
    process_dsl(dsl, params)
    q
  end
end

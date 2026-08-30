# frozen_string_literal: true

# Builds a plain tags search string from PostSearch::Fields form field values (the "into text"
# direction) - the reverse of PostSearch::FormParser.
module PostSearch
  class QueryBuilder
    def self.build(params)
      new(params).build
    end

    def initialize(params)
      @params = params || {}
    end

    def build
      (general_tag_tokens + character_group_tokens + bool_group_tokens + field_tokens).join(" ")
    end

    private

    def general_tag_tokens
      @params[:general_tags].to_s.split
    end

    def character_group_tokens
      groups = @params[:character_groups]
      groups = groups.respond_to?(:values) ? groups.values : Array(groups)

      groups.filter_map do |g|
        names = Array(g[:tags]).flat_map { |t| t.to_s.split }
        next if names.empty?

        prefix = g[:mode].to_s == "must_not" ? "-" : ""
        "#{prefix}{#{names.join(' ')}}"
      end
    end

    # (a b) / -(a b) / ~(a b): the group's own tag text is kept as a raw string rather than
    # split/rejoined like character_group_tokens does, so a group richer than the simple
    # textarea UI edits for (nested groups, metatags) still round-trips intact. The form field
    # is named "...[tags][]" (a real submission arrives as a one-element array because of that
    # trailing [], same as character_groups) - Array(...).first unwraps it back to the single
    # string it always actually is, without the flat_map/split that would tear a nested group
    # or quoted metatag value apart.
    def bool_group_tokens
      groups = @params[:bool_groups]
      groups = groups.respond_to?(:values) ? groups.values : Array(groups)

      groups.filter_map do |g|
        tags = Array(g[:tags]).first.to_s.strip
        next if tags.blank?

        prefix = { "must_not" => "-", "should" => "~" }[g[:mode].to_s] || ""
        "#{prefix}(#{tags})"
      end
    end

    # Many metatags can be given more than once (e.g. "locked:rating locked:status" requires
    # both) - a field's value/mode params are usually a plain scalar (one piece in the search
    # builder, or a script calling QueryBuilder directly), but become parallel arrays once
    # there's more than one piece for the same field. Array() normalizes both to a list, so a
    # single value round-trips exactly as before.
    def field_tokens
      PostSearch::Fields.fields.flat_map do |field|
        values = Array(@params[field.metatag]).map { |v| v.to_s.strip }.compact_blank
        next [] if values.empty?

        modes = Array(@params[:"#{field.metatag}_mode"])
        values.each_with_index.map do |value, i|
          if field.type == :boolean
            "#{field.metatag}:#{value}"
          else
            prefix = { "must_not" => "-", "should" => "~" }[modes[i].to_s] || ""
            value = %("#{value}") if value.include?(" ")
            "#{prefix}#{field.metatag}:#{value}"
          end
        end
      end
    end
  end
end

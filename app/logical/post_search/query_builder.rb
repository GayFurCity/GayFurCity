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
      (general_tag_tokens + character_group_tokens + field_tokens).join(" ")
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

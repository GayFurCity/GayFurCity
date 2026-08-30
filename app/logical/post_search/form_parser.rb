# frozen_string_literal: true

# Parses a plain tags search string into PostSearch::Fields form field values (the "from text"
# direction, used to pre-fill /posts/search from an existing search) - the reverse of
# PostSearch::QueryBuilder. Anything that isn't a {} group or a metatag matching a known field
# (either its canonical name, or one of METATAG_ALIASES) is left as a general/bare tag, so
# round-tripping through the form never silently drops part of the original query.
module PostSearch
  class FormParser
    Result = Struct.new(:general_tags, :character_groups, :field_values, :field_modes, keyword_init: true) do
      # A friendlier shape for the GET .json response than the raw struct - merges
      # field_values/field_modes (parallel hashes keyed by metatag) into one fields hash, so a
      # consumer doesn't have to zip the two together by key itself.
      def as_json(*)
        fields = field_values.each_with_object({}) do |(metatag, value), hash|
          hash[metatag] = { value: value, mode: field_modes[metatag] }.compact
        end
        { general_tags: general_tags, character_groups: character_groups, fields: fields }
      end
    end

    METATAG_ALIASES = {
      "type"      => "filetype",
      "fav"       => "favoritedby",
      "comm"      => "commenter",
      "votedup"   => "upvote",
      "voteddown" => "downvote",
    }.freeze

    MODE_PREFIXES = { "-" => "must_not", "~" => "should" }.freeze

    def self.parse(tags_string)
      new(tags_string).parse
    end

    def initialize(tags_string)
      @tags_string = tags_string.to_s
    end

    def parse
      general = []
      groups = []
      values = {}
      modes = {}

      TagQuery.scan(@tags_string).each do |token|
        if token =~ /\A(-?)\{(.*)\}\z/
          names = Regexp.last_match(2).split
          groups << { tags: names.join(" "), mode: Regexp.last_match(1) == "-" ? "must_not" : "must" } if names.any?
          next
        end

        metatag_name, value = token.split(":", 2)
        if value.blank?
          general << token
          next
        end

        prefix = metatag_name[0]
        mode = MODE_PREFIXES[prefix] || "must"
        bare_name = MODE_PREFIXES.key?(prefix) ? metatag_name[1..] : metatag_name
        bare_name = METATAG_ALIASES.fetch(bare_name.downcase, bare_name.downcase)

        field = PostSearch::Fields.find(bare_name)
        if field
          add_occurrence(values, field.metatag, value.delete_prefix('"').delete_suffix('"'))
          add_occurrence(modes, field.metatag, mode) if field.negatable
        else
          general << token
        end
      end

      Result.new(general_tags: general.join(" "), character_groups: groups, field_values: values, field_modes: modes)
    end

    private

    # Many metatags can be given more than once (e.g. "locked:rating locked:status" requires
    # both) - the first occurrence stays a plain scalar (so a single-value search round-trips
    # exactly as before), and only becomes an array once a second occurrence shows up.
    def add_occurrence(hash, key, value)
      if hash.key?(key)
        hash[key] = Array(hash[key]) + [value]
      else
        hash[key] = value
      end
    end
  end
end

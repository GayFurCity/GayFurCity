# frozen_string_literal: true

# Parses a plain tags search string into PostSearch::Fields form field values (the "from text"
# direction, used to pre-fill /posts/search from an existing search) - the reverse of
# PostSearch::QueryBuilder. Anything that isn't a {} group or a metatag matching a known field
# (either its canonical name, or one of METATAG_ALIASES) is left as a general/bare tag, so
# round-tripping through the form never silently drops part of the original query.
module PostSearch
  class FormParser
    Result = Struct.new(:general_tags, :character_groups, :bool_groups, :field_values, :field_modes, keyword_init: true) do
      # A friendlier shape for the GET .json response than the raw struct - merges
      # field_values/field_modes (parallel hashes keyed by metatag) into one fields hash, so a
      # consumer doesn't have to zip the two together by key itself. Each bool_groups entry gets
      # the same treatment for its own nested field_values/field_modes.
      def as_json(*)
        { general_tags: general_tags, character_groups: character_groups, bool_groups: bool_groups.map { |g| bool_group_as_json(g) }, fields: fields_as_json(field_values, field_modes) }
      end

      private

      def fields_as_json(values, modes)
        values.each_with_object({}) do |(metatag, value), hash|
          hash[metatag] = { value: value, mode: modes[metatag] }.compact
        end
      end

      def bool_group_as_json(group)
        { tags: group[:tags], mode: group[:mode], fields: fields_as_json(group[:field_values], group[:field_modes]) }
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
      scanned = scan(@tags_string, extract_bool_groups: true)

      bool_groups = scanned[:bool_groups].map do |mode, inner_text|
        inner = scan(inner_text, extract_bool_groups: false)
        { tags: inner[:general].join(" "), mode: mode, field_values: inner[:values], field_modes: inner[:modes] }
      end

      Result.new(
        general_tags:     scanned[:general].join(" "),
        character_groups: scanned[:character_groups],
        bool_groups:      bool_groups,
        field_values:     scanned[:values],
        field_modes:      scanned[:modes],
      )
    end

    private

    # Shared token-classification loop, used both for the top-level tags string and recursively
    # for each () group's own inner text (extract_bool_groups: false there - a group nested
    # inside another group isn't broken down further, just kept as raw text in :general, since
    # the search builder's Tag Group piece doesn't support editing a nested group structurally).
    def scan(text, extract_bool_groups:)
      general = []
      character_groups = []
      bool_group_tokens = []
      values = {}
      modes = {}

      TagQuery.scan(text).each do |token|
        if token =~ /\A(-?)\{(.*)\}\z/
          names = Regexp.last_match(2).split
          character_groups << { tags: names.join(" "), mode: Regexp.last_match(1) == "-" ? "must_not" : "must" } if names.any?
          next
        end

        if (match = token.match(/\A([-~]?)\((.*)\)\z/m))
          if extract_bool_groups
            inner = match[2].strip
            bool_group_tokens << [MODE_PREFIXES[match[1]] || "must", inner] if inner.present?
          else
            general << token
          end
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

      { general: general, character_groups: character_groups, bool_groups: bool_group_tokens, values: values, modes: modes }
    end

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

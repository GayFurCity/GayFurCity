# frozen_string_literal: true

# Extracts {tag group} blocks from a raw tag_string. Used for manual/API tag
# editing; the UI never needs this, it submits ungrouped_tag_string and
# character_groups_attributes directly instead.
class TagStringParser
  Result = Struct.new(:tags, :groups, :error, keyword_init: true) do
    def valid?
      error.nil?
    end
  end

  def self.parse(text)
    text = text.to_s
    groups = []

    flat = text.gsub(/\{([^{}]*)\}/) do
      names = Regexp.last_match(1).split.uniq
      groups << names if names.any?
      " "
    end

    if flat.include?("{") || flat.include?("}")
      return Result.new(tags: [], groups: [], error: "tag group braces are unbalanced or nested")
    end

    Result.new(tags: flat.split.uniq, groups: groups, error: nil)
  end
end

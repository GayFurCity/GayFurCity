# frozen_string_literal: true

# A cheap, admin-tunable ceiling on whitespace-separated tokens in an anonymous search, checked
# in TagQuery#initialize before any real parsing happens - independent of tag_query_limit (which
# is only enforced after parsing, and could otherwise be set to -1/unlimited for anonymous).
class AddAnonymousHardTagLimitToConfig < ExtendedMigration[8.1]
  def change
    add_column(:config, :anonymous_hard_tag_limit, :integer, null: false, default: 40)

    Config.delete_cache
  end
end

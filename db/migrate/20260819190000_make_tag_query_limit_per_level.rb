# frozen_string_literal: true

# tag_query_limit was a single flat number for everyone; make it per-user-level like the other
# *_limit config options (bur_entry_limit, followed_tag_limit, etc.). The existing flat value
# becomes the anonymous-and-up default, so behavior doesn't change until an admin splits it out.
class MakeTagQueryLimitPerLevel < ExtendedMigration[8.1]
  with_config_override!

  def change
    remove_column(:config, :tag_query_limit, :integer, default: 40, null: false)
    add_column(:config, :tag_query_limit, :jsonb, default: { User::Levels::ANONYMOUS => 40 }, null: false)

    Config.delete_cache
  end
end

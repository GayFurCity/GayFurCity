# frozen_string_literal: true

class AddPostFlagNoteMaxSizeToConfig < ExtendedMigration[7.1]
  with_config_override!

  def change
    add_column(:config, :post_flag_note_max_size, :integer, default: 10_000, null: false)
    Config.delete_cache
  end
end

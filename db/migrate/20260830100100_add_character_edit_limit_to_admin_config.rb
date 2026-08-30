# frozen_string_literal: true

class AddCharacterEditLimitToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :character_edit_limit, :integer, default: 25, null: false)
    add_column(:admin_config, :character_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
  end
end

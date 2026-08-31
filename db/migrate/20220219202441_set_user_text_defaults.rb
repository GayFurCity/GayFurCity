# frozen_string_literal: true

class SetUserTextDefaults < ActiveRecord::Migration[6.1]
  def change
    change_column_default(:users, :profile_about, from: nil, to: "")
    change_column_default(:users, :profile_artinfo, from: nil, to: "")
  end
end

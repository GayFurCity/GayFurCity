# frozen_string_literal: true

class AddUserAboutIndicies < ActiveRecord::Migration[7.0]
  def change
    add_index(:users, "(to_tsvector('english', profile_about))", using: :gin)
    add_index(:users, "(to_tsvector('english', profile_artinfo))", using: :gin)
    add_index(:users, "(lower(profile_about)) gin_trgm_ops", using: :gin, name: "index_users_on_lower_profile_about_trgm")
    add_index(:users, "(lower(profile_artinfo)) gin_trgm_ops", using: :gin, name: "index_users_on_lower_profile_artinfo_trgm")
  end
end

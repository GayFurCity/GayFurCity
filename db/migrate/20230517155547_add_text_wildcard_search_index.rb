# frozen_string_literal: true

class AddTextWildcardSearchIndex < ActiveRecord::Migration[7.0]
  def change
    add_gin_index(:blips, :body)
    add_gin_index(:comments, :body)
    add_gin_index(:dmails, :body)
    add_gin_index(:forum_posts, :body)
    add_gin_index(:forum_topics, :title)
    add_gin_index(:notes, :body)
    add_gin_index(:user_feedback, :body)
    add_gin_index(:wiki_pages, :body)
    add_gin_index(:wiki_pages, :title)
  end

  def add_gin_index(table, column)
    add_index(table, "(lower(#{column})) gin_trgm_ops", using: :gin, name: "index_#{table}_on_lower_#{column}_trgm")
  end
end

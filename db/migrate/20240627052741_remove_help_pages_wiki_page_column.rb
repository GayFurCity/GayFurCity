# frozen_string_literal: true

class RemoveHelpPagesWikiPageColumn < ActiveRecord::Migration[7.1]
  def change
    change_column_null(:help_pages, :wiki_page_id, false)
    remove_column(:help_pages, :wiki_page, :string, null: false)
  end
end

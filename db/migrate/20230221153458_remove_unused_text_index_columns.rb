# frozen_string_literal: true

class RemoveUnusedTextIndexColumns < ActiveRecord::Migration[7.0]
  def change
    drop_trigger_and_column(:blips, :body)
    drop_trigger_and_column(:comments, :body)
    drop_trigger_and_column(:dmails, :message)
    drop_trigger_and_column(:forum_posts, :text)
    drop_trigger_and_column(:forum_topics, :text)
    drop_trigger_and_column(:notes, :body)
    drop_trigger_and_column(:wiki_pages, :body)
  end

  def drop_trigger_and_column(table, column)
    reversible do |r|
      r.up do
        execute("DROP TRIGGER trigger_#{table}_on_update ON #{table}")
        remove_column(table, "#{column}_index")
      end
      r.down do
        add_column(table, "#{column}_index", :tsvector, null: false, index: true)
        execute("CREATE TRIGGER trigger_#{table}_on_update BEFORE INSERT OR UPDATE ON #{table} FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('#{column}_index', 'pg_catalog.english', '#{column}')")
      end
    end
  end
end

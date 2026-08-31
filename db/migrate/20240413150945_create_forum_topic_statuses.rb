# frozen_string_literal: true

class CreateForumTopicStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table(:forum_topic_statuses) do |t|
      t.references(:user, null: false)
      t.references(:forum_topic, null: false)
      t.datetime(:subscription_last_read_at)
      t.boolean(:subscription, null: false, default: false)
      t.boolean(:mute, null: false, default: false)
      t.timestamps
    end

    drop_table(:forum_subscriptions, id: :integer) do |t|
      t.integer(:user_id)
      t.integer(:forum_topic_id)
      t.datetime(:last_read_at)
      t.string(:delete_key)
      t.index(:user_id)
      t.index(:forum_topic_id)
    end
  end
end

# frozen_string_literal: true

class NewsUpdate < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  validates(:message, length: { minimum: 1, maximum: -> { AdminConfig.instance.news_update_max_size } })

  after_destroy(:invalidate_cache)
  after_save(:invalidate_cache)

  modactions(:news)
    .add(:create, :creator, on: :create) { { message: message } }
    .add(:update, :updater, on: :update) { { message: message, old_message: message_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { message: message } }

  def self.recent
    Cache.fetch("recent_news", expires_in: 1.day) do
      order(id: :desc).first
    end
  end

  def invalidate_cache
    Cache.delete("recent_news")
  end

  def self.available_includes
    %i[creator updater]
  end
end

# frozen_string_literal: true

require("net/smtp")

class ForumTopicStatus < ApplicationRecord
  belongs_to(:forum_topic)
  belongs_to_user(:user)

  scope(:subscriptions, -> { where(subscription: true) })
  scope(:state, -> { where.lt(subscription_last_read_at: 3.months.ago) })

  def self.prune_subscriptions!
    subscriptions.stale.delete_all
  end

  def self.process_all_subscriptions!
    ForumTopicStatus.subscriptions.find_each do |subscription|
      forum_topic = subscription.forum_topic
      if forum_topic.updated_at > subscription.subscription_last_read_at
        forum_posts = forum_topic.posts.where("created_at > ?", subscription.subscription_last_read_at).order(id: :desc)
        begin
          UserMailer.forum_notice(subscription.user, forum_topic, forum_posts).deliver_now
        rescue Net::SMTPError, Mail::Sendmail::DeliveryError
          # Ignore
        end
        subscription.update_attribute(:subscription_last_read_at, forum_topic.updated_at)
      end
    end
  end

  def self.available_includes
    %i[forum_topic user]
  end
end

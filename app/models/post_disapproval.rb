# frozen_string_literal: true

class PostDisapproval < ApplicationRecord
  belongs_to_user(:user, ip: true)
  belongs_to(:post)
  validates(:post_id, uniqueness: { scope: %i[user_id], message: "have already hidden this post" })
  validates(:reason, inclusion: { in: %w[borderline_quality borderline_relevancy other] })
  validates(:message, length: { maximum: -> { AdminConfig.instance.disapproval_message_max_size } })

  scope(:with_message, -> { where.not(message: [nil, ""]) })
  scope(:without_message, -> { where(message: [nil, ""]) })
  scope(:poor_quality, -> { where(reason: "borderline_quality") })
  scope(:not_relevant, -> { where(reason: "borderline_relevancy") })
  after_save(:update_post_index)

  module SearchMethods
    def post_tags_match(query, user)
      where(post_id: Post.tag_match_sql(query, user))
    end

    def query_dsl
      super
        .field(:post_id)
        .field(:message)
        .field(:reason, like: true)
        .field(:ip_addr, :user_ip_addr)
        .custom(:post_tags_match, ->(q, v, user) { q.post_tags_match(v, user) })
        .custom(:has_message, ->(q, v) { q.if(v, q.with_message).else(q.without_message) })
        .association(:user, :creator)
    end

    def apply_order(params)
      order_with(%i[post_id], params[:order])
    end
  end

  extend(SearchMethods)

  def update_post_index
    post.update_index
  end

  def self.available_includes
    %i[post user]
  end

  def visible?(user)
    user.is_approver?
  end
end

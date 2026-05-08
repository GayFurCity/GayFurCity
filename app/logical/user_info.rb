# frozen_string_literal: true

class UserInfo
  include(ActiveModel::Serializers::JSON)

  THROTTLE_LIST = User::LimitMethods.throttles.map(&:name).sort
  attr_reader(:user)

  def initialize(user)
    @user = user
  end

  class Throttle
    include(ActiveModel::Serializers::JSON)

    attr_reader(:user, :throttle, :bypass, :newbie, :level, :limit)

    def initialize(user, throttle)
      @user = user
      @throttle = throttle
      @bypass = throttle.bypass?(user)
      @newbie = throttle.newbie?(user)
      @level = throttle.level?(user)
      # if they are any of these the limit doesn't matter, so don't bother calculating it
      @limit = @bypass || @newbie || !@level ? nil : throttle.limit(user)
    end

    def url
      r = Rails.application.routes.url_helpers
      case throttle.name
      when :artist_edit
        r.artist_versions_path(search: { updater_id: user.id })
      when :comment
        r.comments_path(search: { creator_id: user.id }, group_by: "comment")
      when :comment_vote
        r.url_for(controller: "comments/votes", action: :index, search: { user_id: user.id })
      when :dmail, :dmail_day, :dmail_minute, :dmail_restricted
        r.dmails_path(search: { from_id: user.id })
      when :forum_post
        r.forum_posts_path(search: { creator_id: user.id })
      when :forum_vote
        r.url_for(controller: "forums/posts/votes", action: :index, search: { user_id: user.id })
      when :note_edit
        r.note_versions_path(search: { updater_id: user.id })
      when :pool, :pool_edit, :pool_post_edit
        r.pool_versions_path(search: { updater_id: user.id })
      when :post_appeal
        r.post_appeals_path(search: { creator_id: user.id })
      when :post_edit
        r.post_versions_path(search: { updater_id: user.id })
      when :post_flag
        r.post_flags_path(search: { creator_id: user.id })
      when :post_vote
        r.url_for(controller: "posts/votes", action: :index, search: { user_id: user.id })
      when :suggest_tag
        r.forum_topics_path(search: { creator_id: user.id, category_id: Config.instance.alias_and_implication_forum_category })
      when :ticket
        r.tickets_path(search: { creator_id: user.id })
      when :wiki_edit
        r.wiki_page_versions_path(search: { updater_id: user.id })
      end
    end

    def serializable_hash(*)
      %i[throttle bypass newbie level limit].index_with { |k| send(k) }
    end
  end

  def throttles
    @throttles ||= User::LimitMethods.throttles.to_h { |throttle| [throttle.name, Throttle.new(user, throttle)] }
  end

  def api
    {
      limit:     user.remaining_api_limit,
      remaining: user.api_burst_limit,
    }
  end

  def serializable_hash(*)
    {
      api:       api,
      throttles: throttles.map(&:second),
    }
  end
end

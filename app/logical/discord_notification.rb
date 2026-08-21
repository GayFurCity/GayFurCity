# frozen_string_literal: true

class DiscordNotification
  GREEN = 0x008000
  YELLOW = 0xFFA500
  RED = 0xFF0000

  attr_accessor(:record, :action)

  def initialize(record, action)
    @record = record
    @action = action
  end

  def webhook_url
    GayFurCity.config.discord.webhook_url
  end

  def create_embed
    embeds = []
    case record
    when Artist
      embeds << { color: GREEN, title: "Artist Created", description: "Name: #{record.name}", url: r.artist_url(record), author: a(record.creator) }
    when Ban
      embeds << { color: RED, title: "Ban Created", description: "User: #{u(record.user)}", url: r.ban_url(record), author: a(record.creator) }
    when BulkUpdateRequest
      embeds << { color: GREEN, title: "Bulk Update Request Created", url: r.bulk_update_request_url(record), author: a(record.creator) }
    when Comment
      embeds << { color: GREEN, title: "Comment Created", url: r.comment_url(record), author: a(record.creator) }
    when CommentVote
      embeds << { color: GREEN, title: "Comment Vote Created", url: r.url_for(controller: "comments/votes", action: "index", search: { comment_id: record.comment_id }, anchor: "comment-#{record.id}"), author: a(record.user) }
    when Favorite
      embeds << { color: GREEN, title: "Favorite Created", url: r.favorite_url(record), author: a(record.user) }
    when ForumPost
      return if record == record.topic.original_post
      embeds << { color: GREEN, title: "Forum Post Created", description: "Topic: [#{record.topic.title}](#{r.forum_topic_url(record.topic)})\nCategory: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_post_url(record), author: a(record.creator) }
    when ForumPostVote
      embeds << { color: GREEN, title: "Forum Post Vote Created", url: r.url_for(controller: "forums/posts/votes", action: "index", search: { forum_post_id: record.forum_post_id }, anchor: "forum-post-vote-#{record.id}"), author: a(record.user) }
    when ForumTopic
      embeds << { color: GREEN, title: "Forum Topic Created", description: "Category: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_topic_url(record), author: a(record.creator) }
    when Note
      embeds << { color: GREEN, title: "Note Created", url: r.note_url(record), author: a(record.creator) }
    when Pool
      embeds << { color: GREEN, title: "Pool Created", url: r.pool_url(record), author: a(record.creator) }
    when Post
      embeds << { color: GREEN, title: "Post Created", url: r.post_url(record), author: a(record.uploader) }
    when PostAppeal
      embeds << { color: GREEN, title: "Post Appeal Created", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_appeals_url(search: { post_id: record.post_id }, anchor: "post-appeal-#{record.id}"), author: a(record.creator) }
    when PostEvent
      case record.action
      when "deleted"
        embeds << { color: RED, title: "Post Deleted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "undeleted"
        embeds << { color: GREEN, title: "Post Undeleted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "approved"
        embeds << { color: GREEN, title: "Post Approved", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "unapproved"
        embeds << { color: RED, title: "Post Unapproved", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "flag_created"
        embeds << { color: RED, title: "Post Flag Created", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_flags_url(search: { post_id: record.post_id }, anchor: "post-flag-#{record.id}"), author: a(record.creator) }
      when "flag_removed"
        embeds << { color: GREEN, title: "Post Flag Removed", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_flags_url(search: { post_id: record.post_id }, anchor: "post-flag-#{record.id}"), author: a(record.creator) }
      when "favorites_moved"
        embeds << { color: GREEN, title: "Post Favorites Moved", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "favorites_received"
        embeds << { color: GREEN, title: "Post Favorites Received", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "rating_locked"
        embeds << { color: GREEN, title: "Post Rating Locked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "rating_unlocked"
        embeds << { color: RED, title: "Post Rating Unlocked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "status_locked"
        embeds << { color: GREEN, title: "Post Status Locked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "status_unlocked"
        embeds << { color: RED, title: "Post Status Unlocked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "note_locked"
        embeds << { color: GREEN, title: "Post Note Locked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "note_unlocked"
        embeds << { color: RED, title: "Post Note Unlocked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "replacement_accepted"
        embeds << { color: GREEN, title: "Post Replacement Accepted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_replacements_url(search: { post_id: record.post_id }, anchor: "post-replacement-#{record.id}"), author: a(record.creator) }
      when "replacement_rejected"
        embeds << { color: RED, title: "Post Replacement Rejected", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_replacements_url(search: { post_id: record.post_id }, anchor: "post-replacement-#{record.id}"), author: a(record.creator) }
      when "replacement_promoted"
        embeds << { color: GREEN, title: "Post Replacement Promoted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_replacements_url(search: { post_id: record.post_id }, anchor: "post-replacement-#{record.id}"), author: a(record.creator) }
      when "replacement_deleted"
        embeds << { color: RED, title: "Post Replacement Deleted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_replacements_url(search: { post_id: record.post_id }, anchor: "post-replacement-#{record.id}"), author: a(record.creator) }
      when "expunged"
        embeds << { color: RED, title: "Post Expunged", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "comment_disabled"
        embeds << { color: RED, title: "Post Comment Disabled", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "comment_enabled"
        embeds << { color: GREEN, title: "Post Comment Enabled", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "comment_locked"
        embeds << { color: GREEN, title: "Post Comment Locked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "comment_unlocked"
        embeds << { color: RED, title: "Post Comment Unlocked", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "changed_bg_color"
        embeds << { color: GREEN, title: "Post Background Color Changed", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "changed_thumbnail_frame"
        embeds << { color: GREEN, title: "Post Thumbnail Frame Changed", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      when "appeal_created"
        embeds << { color: GREEN, title: "Post Appeal Created", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_appeals_url(search: { post_id: record.post_id }, anchor: "post-appeal-#{record.id}"), author: a(record.creator) }
      when "appeal_accepted"
        embeds << { color: GREEN, title: "Post Appeal Accepted", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_appeals_url(search: { post_id: record.post_id }, anchor: "post-appeal-#{record.id}"), author: a(record.creator) }
      when "appeal_rejected"
        embeds << { color: RED, title: "Post Appeal Rejected", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_appeals_url(search: { post_id: record.post_id }, anchor: "post-appeal-#{record.id}"), author: a(record.creator) }
      when "copied_notes"
        embeds << { color: GREEN, title: "Post Notes Copied", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      else
        embeds << { color: GREEN, title: "Post Event Created", description: "Type: #{record.action}\nPost: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_events_url(search: { post_id: record.post_id }, anchor: "post-event-#{record.id}"), author: a(record.creator) }
      end
    when PostFlag
      embeds << { color: RED, title: "Post Flag Created", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_flags_url(search: { post_id: record.post_id }, anchor: "post-flag-#{record.id}"), author: a(record.creator) }
    when PostReplacement
      embeds << { color: GREEN, title: "Post Replacement Created", description: "Post: [#{record.post_id}](#{r.post_url(record.post_id)})", url: r.post_replacements_url(search: { post_id: record.post_id }, anchor: "post-replacement-#{record.id}"), author: a(record.creator) }
    when PostReplacementMediaAsset
      embeds << { color: GREEN, title: "Post Replacement Media Asset Created", url: r.post_replacement_media_assets_url(search: { id: record.id }), author: a(record.creator) }
    when PostSet
      embeds << { color: GREEN, title: "Post Set Created", url: r.post_set_url(record), author: a(record.creator) }
    when PostVote
      embeds << { color: GREEN, title: "Post Vote Created", url: r.url_for(controller: "posts/votes", action: "index", search: { post_id: record.post_id }, anchor: "post-vote-#{record.id}"), author: a(record.user) }
    when TagAlias
      embeds << { color: GREEN, title: "Tag Alias Created", description: "Antecedent: #{record.antecedent_name}\nConsequent: #{record.consequent_name}", url: r.tag_alias_url(record), author: a(record.creator) }
    when TagFollower
      embeds << { color: GREEN, title: "Tag Follower Added", description: "Tag: #{record.tag.name}", url: r.followers_tag_url(record.tag, anchor: "tag-follower-#{record.id}"), author: a(record.user) }
    when TagImplication
      embeds << { color: GREEN, title: "Tag Implication Created", description: "Antecedent: #{record.antecedent_name}\nConsequent: #{record.consequent_name}", url: r.tag_implication_url(record), author: a(record.creator) }
    when Ticket
      embeds << { color: GREEN, title: "Ticket Created", url: r.ticket_url(record), author: a(record.creator) }
    when User
      embeds << { color: GREEN, title: "User Created", description: "Name: #{record.name}", url: r.user_url(record), author: a(record) }
    when UploadMediaAsset
      embeds << { color: GREEN, title: "Upload Media Asset Created", url: r.upload_media_assets_url(search: { id: record.id }), author: a(record.creator) }
    when UserFeedback
      embeds << { color: GREEN, title: "User Feedback Created", url: r.user_feedback_url(record), author: a(record.creator) }
    when WikiPage
      embeds << { color: GREEN, title: "Wiki Page Created", url: r.wiki_page_url(record), author: a(record.creator) }
    end
    embeds
  rescue Exception => e
    ExceptionLog.add!(e, source: "DiscordNotification#create_embed", record_type: record.class.name, record_id: record.id)
  end

  def destroy_embed
    embeds = []
    case record
    when Artist
      embeds << { color: RED, title: "Artist Deleted", description: "Name: #{record.name}", url: r.artist_url(record), author: a(record.creator) }
    when Ban
      embeds << { color: GREEN, title: "Ban Deleted", description: "User: #{u(record.user)}", url: r.ban_url(record), author: a(record.creator) }
    when Comment
      embeds << { color: RED, title: "Comment Deleted", url: r.comment_url(record), author: a(record.creator) }
    when CommentVote
      embeds << { color: RED, title: "Comment Vote Removed", url: r.url_for(controller: "comments/votes", action: "index", search: { comment_id: record.comment_id }, anchor: "comment-#{record.id}"), author: a(record.user) }
    when Favorite
      embeds << { color: RED, title: "Favorite Deleted", url: r.favorite_url(record), author: a(record.user) }
    when ForumPost
      embeds << { color: RED, title: "Forum Post Deleted", description: "Topic: [#{record.topic.title}](#{r.forum_topic_url(record.topic)})\nCategory: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_post_url(record), author: a(record.creator) }
    when ForumPostVote
      embeds << { color: RED, title: "Forum Post Vote Removed", url: r.url_for(controller: "forums/posts/votes", action: "index", search: { forum_post_id: record.forum_post_id }, anchor: "forum-post-vote-#{record.id}"), author: a(record.user) }
    when ForumTopic
      embeds << { color: RED, title: "Forum Topic Deleted", description: "Category: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_topic_url(record), author: a(record.creator) }
    when Note
      embeds << { color: RED, title: "Note Deleted", url: r.note_url(record), author: a(record.creator) }
    when Pool
      embeds << { color: RED, title: "Pool Deleted", url: r.pool_url(record), author: a(record.creator) }
    when Post
      embeds << { color: RED, title: "Post Deleted", url: r.post_url(record), author: a(record.uploader) }
    when PostSet
      embeds << { color: RED, title: "Post Set Deleted", url: r.post_set_url(record), author: a(record.creator) }
    when PostVote
      embeds << { color: RED, title: "Post Vote Removed", url: r.url_for(controller: "posts/votes", action: "index", search: { post_id: record.post_id }, anchor: "post-vote-#{record.id}"), author: a(record.user) }
    when TagFollower
      embeds << { color: RED, title: "Tag Follower Removed", description: "Tag: #{record.tag.name}", url: r.followers_tag_url(record.tag, anchor: "tag-follower-#{record.id}"), author: a(record.user) }
    when UserFeedback
      embeds << { color: RED, title: "User Feedback Deleted", url: r.user_feedback_url(record), author: a(record.creator) }
    when WikiPage
      embeds << { color: RED, title: "Wiki Page Deleted", url: r.wiki_page_url(record), author: a(record.creator) }
    end
    embeds
  rescue Exception => e
    ExceptionLog.add!(e, source: "DiscordNotification#destroy_embed", record_type: record.class.name, record_id: record.id)
  end

  def update_embed
    embeds = []
    case record
    when Artist
      if artist.is_locked? && !artist.is_locked_before_last_save
        embeds << { color: GREEN, title: "Artist Locked", description: "Name: #{record.name}", url: r.artist_url(record), author: a(record.updater) }
      elsif !artist.is_locked? && artist.is_locked_before_last_save
        embeds << { color: RED, title: "Artist Unlocked", description: "Name: #{record.name}", url: r.artist_url(record), author: a(record.updater) }
      end
      embeds << { color: YELLOW, title: "Artist Updated", description: "Name: #{record.name}", url: r.artist_url(record), author: a(record.updater) }
    when Ban
      embeds << { color: YELLOW, title: "Ban Updated", description: "User: #{u(record.user)}", url: r.ban_url(record), author: a(record.creator) }
    when BulkUpdateRequest
      embeds << { color: YELLOW, title: "Bulk Update Request Updated", url: r.bulk_update_request_url(record), author: a(record.updater) }
    when Comment
      if record.is_hidden? && !record.is_hidden_before_last_save
        embeds << { color: RED, title: "Comment Hidden", url: r.comment_url(record), author: a(record.updater) }
      elsif !record.is_hidden? && record.is_hidden_before_last_save
        embeds << { color: GREEN, title: "Comment Unhidden", url: r.comment_url(record), author: a(record.updater) }
      end
      if record.is_sticky? && !record.is_sticky_before_last_save
        embeds << { color: GREEN, title: "Comment Stickied", url: r.comment_url(record), author: a(record.updater) }
      elsif !record.is_sticky? && record.is_sticky_before_last_save
        embeds << { color: RED, title: "Comment Unstickied", url: r.comment_url(record), author: a(record.updater) }
      end
      embeds << { color: YELLOW, title: "Comment Updated", url: r.comment_url(record), author: a(record.updater) }
    when ForumPost
      if record.is_hidden? && !record.is_hidden_before_last_save
        embeds << { color: RED, title: "Forum Post Hidden", description: "Topic: [#{record.topic.title}](#{r.forum_topic_url(record.topic)})\nCategory: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_post_url(record), author: a(record.updater) }
      elsif !record.is_hidden? && record.is_hidden_before_last_save
        embeds << { color: GREEN, title: "Forum Post Unhidden", description: "Topic: [#{record.topic.title}](#{r.forum_topic_url(record.topic)})\nCategory: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_post_url(record), author: a(record.updater) }
      end
      embeds << { color: YELLOW, title: "Forum Post Updated", description: "Topic: [#{record.topic.title}](#{r.forum_topic_url(record.topic)})\nCategory: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_post_url(record), author: a(record.updater) }
    when ForumTopic
      if record.is_locked? && !record.is_locked_before_last_save
        embeds << { color: RED, title: "Forum Topic Locked", description: "Category: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_topic_url(record), author: a(record.updater) }
      elsif !record.is_locked? && record.is_locked_before_last_save
        embeds << { color: GREEN, title: "Forum Topic Unlocked", description: "Category: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_topic_url(record), author: a(record.updater) }
      end
      embeds << { color: YELLOW, title: "Forum Topic Updated", description: "Category: [#{record.category.name}](#{r.forum_category_url(record.category)})", url: r.forum_topic_url(record), author: a(record.updater) }
    when Note
      embeds << { color: YELLOW, title: "Note Updated", url: r.note_url(record), author: a(record.updater) }
    when Pool
      embeds << { color: YELLOW, title: "Pool Updated", url: r.pool_url(record), author: a(record.updater) }
    when Post
      changed = Post.get_change_seq_tracked.any? { |attr| record.saved_change_to_attribute?(attr) }
      return unless changed
      embeds << { color: YELLOW, title: "Post Updated", url: r.post_url(record), author: a(record.updater) }
    when PostSet
      embeds << { color: YELLOW, title: "Post Set Updated", url: r.post_set_url(record), author: a(record.updater) }
    when WikiPage
      embeds << { color: YELLOW, title: "Wiki Page Updated", url: r.wiki_page_url(record), author: a(record.updater) }
    end
    embeds
  rescue Exception => e
    ExceptionLog.add!(e, source: "DiscordNotification#update_embed", record_type: record.class.name, record_id: record.id)
  end

  def execute!
    return if webhook_url.blank? || Rails.env.test?

    case action
    when :create
      embeds = create_embed
    when :destroy
      embeds = destroy_embed
    when :update
      embeds = update_embed
    else
      raise(StandardError, "Invalid discord notification type: #{action}")
    end
    return if embeds.blank?

    conn = Faraday.new(GayFurCity.config.faraday_options)
    conn.post(webhook_url, {
      embeds: embeds,
    }.to_json, { content_type: "application/json" })
  rescue Exception => e
    ExceptionLog.add!(e, source: "DiscordNotification#execute!", record_type: record.class.name, record_id: record.id, action: action)
  end

  private

  def r
    Rails.application.routes.url_helpers
  end

  def u(user)
    "[#{user.name}](#{r.user_url(user)})"
  end

  def a(user)
    return nil if user.nil?
    a = { url: r.user_url(user), name: user.name }
    a[:icon_url] = user.avatar.avatar_image_url(User.anonymous) if user.avatar.present?
    a
  end
end

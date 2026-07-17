# frozen_string_literal: true

class UserPresenter < ApplicationPresenter
  attr_reader(:user)

  def initialize(user, helper: nil, view: nil)
    super(helper, view)
    @user = user
  end

  def name
    user.pretty_name
  end

  def level
    user.level_string_pretty
  end

  def ban_reason
    if user.is_banned?
      reason = h.format_text(user.recent_ban.reason)
      edit = h.link_to_enclosed("edit", r.edit_ban_path(user.recent_ban), if: view.policy(user.recent_ban).edit?)
      safe_join([reason, "\n\n Expires ", user.recent_ban.expire_days_tagged, " ", h.link_to_enclosed("#{user.bans.count} #{'ban'.pluralize(user.bans.count)} total", r.bans_path(search: { user_id: user.id })), " ", edit])
    end
  end

  def permissions
    permissions = []

    if user.can_approve_posts?
      permissions << "approve posts"
    end

    if user.unrestricted_uploads?
      permissions << "unrestricted uploads"
    end

    if user.can_upload_in_progress?
      permissions << "upload in-progress posts"
    end

    if user.can_manage_aibur?
      permissions << "manage tag change requests"
    end

    if CurrentUser.user.is_moderator?
      if user.no_flagging?
        permissions << "no flagging"
      end

      if user.no_replacements?
        permissions << "no replacements"
      end

      if user.no_aibur_voting?
        permissions << "no tag change request voting"
      end
    end

    permissions.join(", ")
  end

  def permissions_compact
    perms = permissions.split(", ")
    return Helpers.tag.span(permissions, class: "permissions-list") if perms.length <= 2
    visible = perms.slice(0, 2)
    Helpers.safe_join([Helpers.tag.span(visible.join(", "), class: "permissions-list", data: { short: visible.join(", "), full: perms.join(", ") }), " ", Helpers.link_to("»", "#", title: "Expand", class: "expand-permissions-link"), Helpers.link_to("«", "#", title: "Collapse", class: "collapse-permissions-link", style: "display: none;")])
    # %(<text class="permissions-list" data-short="#{visible.join(', ')}" data-full="#{perms.join(', ')}">#{visible.join(', ')}</text> <a href="#" title="Expand" class="expand-permissions-link">»</a><a title="Collapse" href="#" style="display: none;" class="collapse-permissions-link">«</a>).html_safe
  end

  def upload_limit
    if user.unrestricted_uploads?
      return "none"
    end

    upload_limit_pieces = user.upload_limit_pieces
    Helpers.safe_join([
      Helpers.tag.abbr(user.base_upload_limit, title: "Base Upload Limit"),
      " + (", Helpers.tag.abbr(upload_limit_pieces.approved, title: "Approved Posts"), " / 10)",
      " - (", Helpers.tag.abbr(upload_limit_pieces.deleted, title: "Deleted or Replaced Posts, Rejected Replacements\n#{upload_limit_pieces.deleted_ignore} of your Replaced Posts do not affect your upload limit"), " / 4)",
      " - ", Helpers.tag.abbr(upload_limit_pieces.pending, title: "Pending or Flagged Posts, Pending Replacements"),
      " = ", Helpers.tag.abbr(user.upload_limit, title: "User Upload Limit Remaining"),
    ])
  end

  def artwork(name)
    Post.tag_match(name, CurrentUser.user).limit(10)
  end

  def uploads
    Post.tag_match("user:#{user.name}", CurrentUser.user).limit(8)
  end

  def has_active_uploads?
    (user.post_upload_count - user.post_deleted_count) > 0
  end

  def show_uploads?
    has_active_uploads? || CurrentUser.user.is_moderator?
  end

  def favorites
    ids = Favorite.where(user_id: user.id).order(created_at: :desc).limit(50).pluck(:post_id)[0..7]
    Post.where(id: ids).sort_by { |post| ids.index(post.id) }
  end

  def has_favorites?
    user.favorite_count > 0
  end

  def upload_count
    link_to(user.post_upload_count, Routes.posts_path(tags: "user:#{user.name}"))
  end

  def active_upload_count
    link_to(user.post_active_count, Routes.posts_path(tags: "user:#{user.name}"))
  end

  def deleted_upload_count
    link_to(user.post_deleted_count, Routes.deleted_posts_path(user_id: user.id))
  end

  def replaced_upload_count
    link_to(user.own_post_replaced_count, Routes.post_replacements_path(search: { uploader_id_on_approve: user.id }))
  end

  def rejected_replacements_count
    link_to(user.post_replacement_rejected_count, Routes.post_replacements_path(search: { creator_id: user.id, status: "rejected" }))
  end

  def favorite_count
    link_to(user.favorite_count, Routes.favorites_path(user_id: user.id))
  end

  def comment_count
    link_to(user.comment_count, Routes.comments_path(search: { creator_id: user.id }, group_by: "comment"))
  end

  def commented_posts_count
    link_to(commented_on_posts_count, Routes.posts_path(tags: "commenter:#{user.name} order:comment_bumped"))
  end

  def commented_on_posts_count
    Post.system_count("commenter:#{user.name}", enable_safe_mode: false)
  end

  def post_version_count
    link_to(user.post_update_count, Routes.post_versions_path(lr: user.id, search: { updater_id: user.id }))
  end

  def note_version_count
    link_to(user.note_version_count, Routes.note_versions_path(search: { updater_id: user.id }))
  end

  def noted_posts_count
    count = Post.system_count("noteupdater:#{user.name}", enable_safe_mode: false)
    link_to(count, Routes.posts_path(tags: "noteupdater:#{user.name} order:note"))
  end

  def wiki_page_version_count
    link_to(user.wiki_page_version_count, Routes.wiki_page_versions_path(search: { updater_id: user.id }))
  end

  def artist_version_count
    link_to(user.artist_version_count, Routes.artist_versions_path(search: { updater_id: user.id }))
  end

  def forum_post_count
    link_to(user.forum_post_count, Routes.forum_posts_path(search: { creator_id: user.id }))
  end

  def pool_version_count
    link_to(user.pool_version_count, Routes.pool_versions_path(search: { updater_id: user.id }))
  end

  def flag_count
    link_to(user.flag_count, Routes.post_flags_path(search: { creator_id: user.id }))
  end

  def ticket_count
    link_to(user.ticket_count, Routes.tickets_path(search: { creator_id: user.id }))
  end

  def approval_count
    link_to(Post.where(approver_id: user.id).count, Routes.posts_path(tags: "approver:#{user.name}"))
  end

  def feedbacks
    positive = user.positive_feedback_count
    neutral = user.neutral_feedback_count
    negative = user.negative_feedback_count
    deleted = CurrentUser.user.is_staff? ? user.deleted_feedback_count : 0

    return "0" if (positive + neutral + negative + deleted) == 0

    total_class = (positive - negative) > 0 ? "user-feedback-positive" : "user-feedback-negative"
    total_class = "" if (positive - negative) == 0
    list_html = safe_join([
      (tag.span(positive, class: "user-feedback-positive") if positive > 0),
      (tag.span(neutral, class: "user-feedback-neutral") if neutral > 0),
      (tag.span(negative, class: "user-feedback-negative") if negative > 0),
      (tag.span(deleted, class: "user-feedback-deleted") if deleted > 0),
    ].compact, " ")

    safe_join([
      tag.span(positive - negative, class: total_class),
      " (",
      list_html,
      ")",
    ])
  end

  def previous_names
    safe_join(user.user_name_change_requests.map { |req| link_to(req.original_name, req) }, " -> ")
  end

  def favorite_tags_with_types
    tag_names = user&.favorite_tags.to_s.split
    tag_names = TagAlias.to_aliased(tag_names)
    indices = tag_names.each_with_index.to_h { |x, i| [x, i] }
    tags = Tag.where(name: tag_names).map do |tag|
      {
        name:        tag.name,
        count:       tag.post_count,
        category_id: tag.category,
      }
    end
    tags.sort_by { |entry| indices[entry[:name]] }
  end

  def recent_tags_with_types
    versions = PostVersion.where(updater_id: user.id).where("updated_at > ?", 1.hour.ago).order(id: :desc).limit(150)
    tags = versions.flat_map(&:added_tags)
    tags = tags.tally.sort_by { |tag, count| [-count, tag] }.map(&:first)
    tags = tags.take(50)
    Tag.where(name: tags).map do |tag|
      {
        name:        tag.name,
        count:       tag.post_count,
        category_id: tag.category,
      }
    end
  end

  def age_verified
    return "No" unless user.age_verified?
    blame = user.age_verified_blame
    return "Yes" if blame.blank?
    safe_join(["Yes, by ", h.link_to_user(blame)])
  end

  def policy
    UserPresenterPolicy.new(CurrentUser.user, self)
  end
end

# frozen_string_literal: true

# Display logic for a single replacement card (posts/replacements/_card.html.erb). All
# show_*? gating goes through the real PostReplacementPolicy/TicketPolicy so the card never
# shows an action the controller would actually reject.
class PostReplacementPresenter < Presenter
  # Highlighted-tag -> status icon, shown next to a pending replacement's status.
  STATUS_TAG_ICONS = {
    "avoid_posting"            => :octagon_x,
    "conditional_dnp"          => :octagon_alert,
    "better_version_at_source" => :diamond_plus,
  }.freeze

  attr_reader(:replacement, :user, :actions)

  delegate(:post, to: :replacement)

  def initialize(replacement:, user: CurrentUser.user, timeline: false, expanded: nil, actions: true)
    @replacement = replacement
    @user = user
    @timeline = timeline
    @expanded = expanded.nil? ? (replacement.pending? || replacement.is_current?) : expanded
    @actions = actions
    @policy = PostReplacementPolicy.new(user, replacement)
  end

  def expanded?
    @expanded
  end

  def timeline?
    @timeline
  end

  ##############################
  ##########  Header  ##########
  ##############################

  def card_classes
    classes = ["replacement-card", "is-#{replacement.status}"]
    classes << "is-current" if replacement.is_current?
    classes << "is-expanded" if expanded?
    classes << "has-timeline" if @timeline
    classes.join(" ")
  end

  def highlighted_tags
    return [] unless replacement.pending?
    post.tag_array & PostReplacement::HIGHLIGHTED_TAGS
  end

  def status_tag_icon(tag)
    STATUS_TAG_ICONS[tag]
  end

  ##############################
  ##########  Fields  ##########
  ##############################

  def created_at_label
    replacement.original? ? "Backup created at" : "Created at"
  end

  # "WIDTHxHEIGHT ext (size, DURATIONs)" for either the replacement or the post. A duration
  # is only meaningful for the file actually being shown, so it's included for the post's
  # own details and for a replacement only while that replacement is the post's current file.
  def file_details(record)
    details = "#{record.image_width}x#{record.image_height} #{record.file_ext} "
    details += "(#{record.file_size.to_fs(:human_size, precision: 5)}"
    details += ", #{record.duration}s" if record.is_video? && (record == post || replacement.is_current?)
    "#{details})"
  end

  def show_status_changed_at?
    replacement.updated_at != replacement.created_at
  end

  def sources
    return [] if replacement.source.blank?
    replacement.source_list.partition { |s| !s.start_with?("-") }.flatten
  end

  def show_previous_uploader?
    !replacement.original? && !replacement.pending? && replacement.uploader_on_approve.present?
  end

  def show_penalize_toggle?
    @policy.toggle_penalize? && replacement.approved?
  end

  ##############################
  #########  Actions  ##########
  ##############################

  def show_staff_actions?
    user&.can_approve_posts?
  end

  def show_admin_actions?
    user&.is_admin?
  end

  def show_approve?
    @policy.approve? && (replacement.pending? || replacement.rejected?) && !post.is_deleted?
  end

  def show_reject?
    @policy.reject? && replacement.pending?
  end

  def show_reject_with_reason?
    @policy.reject_with_reason? && replacement.pending?
  end

  # Approving with penalize=false is the "Reset To" action; approve penalizes the
  # current uploader only when it differs from this replacement's creator.
  def approve_penalizes?
    post.uploader != replacement.creator
  end

  def show_promote?
    @policy.promote? && !replacement.is_current? && !replacement.promoted? && !replacement.original?
  end

  def show_reset_to?
    @policy.approve? && replacement.original? && !replacement.metadata_only? && !post.is_deleted?
  end

  def show_transfer?
    @policy.transfer?
  end

  def show_destroy?
    @policy.destroy?
  end
end

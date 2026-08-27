# frozen_string_literal: true

class PostFlag < ApplicationRecord
  class Error < StandardError
  end

  COOLDOWN_PERIOD = 1.day
  MAPPED_REASONS = GayFurCity.config.flag_reasons.to_h { |i| [i[:name], i[:reason]] }

  belongs_to_user(:creator, ip: true, clones: :updater, counter_cache: "post_flag_count")
  resolvable(:updater)
  belongs_to(:post)
  validate(:validate_creator_is_not_limited, on: :create)
  validate(:validate_post)
  validate(:validate_reason)
  validate(:update_reason, on: :create)
  validates(:reason, presence: true)
  validates(:note, length: { maximum: -> { AdminConfig.post_flag_note_max_size } })
  validate(:validate_note_required_for_reason)
  before_save(:update_post)
  after_create(:create_post_event)
  after_commit(:index_post)

  scope(:by_users, -> { where.not(creator: User.system) })
  scope(:by_system, -> { where(creator: User.system) })
  scope(:in_cooldown, -> { by_users.where(created_at: COOLDOWN_PERIOD.ago..) })
  scope(:pending, -> { by_users.where(is_resolved: false) })
  scope(:resolved, -> { where(is_resolved: true) })
  scope(:unresolved, -> { where(is_resolved: false) })
  scope(:deletion, -> { where(is_deletion: true) })
  scope(:flag, -> { where(is_deletion: false) })
  scope(:for_creator, ->(user) { where(creator_id: u2id(user)) })

  attr_accessor(:parent_id, :reason_name, :force_flag)

  module SearchMethods
    def post_tags_match(query, user)
      where(post_id: Post.tag_match_sql(query, user))
    end

    def query_dsl
      super
        .field(:reason_matches, :reason)
        .field(:note_matches, :note)
        .field(:is_resolved)
        .field(:post_id)
        .field(:ip_addr, :creator_ip_addr)
        .custom(:post_tags_match, ->(q, v, user) { q.post_tags_match(v, user) })
        .custom(:type, ->(q, v) { { "flag" => q.flag, "deletion" => q.deletion }.fetch(v, q.none) })
        .custom(:creator_id, method(:creator_id_query).to_proc)
        .custom(:creator_name, method(:creator_name_query).to_proc)
        # TODO: We need access control/blocks for associations
        # .association(:creator)
        .association(:post)
    end

    def creator_id_query(q, value, user)
      value = value.to_s.split(",").map(&:to_i)
      return q.where(creator_id: value) if user.is_moderator?
      q.where.not(
        creator_id: value.reject { |user_id| user.can_view_flagger?(user_id) },
      ).where(creator_id: value)
    end

    def creator_name_query(q, value, user)
      id = User.name_to_id(value)
      creator_id_query(q, id.to_s, user)
    end
  end

  extend(SearchMethods)

  def type
    return :deletion if is_deletion
    :flag
  end

  def update_post
    post.update_column(:is_flagged, true) unless post.is_flagged?
  end

  def index_post
    post.update_index
  end

  def validate_creator_is_not_limited
    return if is_deletion

    if creator.no_flagging?
      errors.add(:creator, "cannot flag posts")
    end

    return if creator.is_janitor?

    allowed = creator.can_post_flag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end

    flag = post.flags.in_cooldown.last
    if flag.present?
      errors.add(:post, "cannot be flagged more than once every #{COOLDOWN_PERIOD.inspect} (last flagged: #{flag.created_at.to_fs(:long)})")
    end
  end

  def validate_post
    errors.add(:post, "is locked and cannot be flagged") if post.is_status_locked? && !(creator.is_admin? || force_flag)
    errors.add(:post, "is deleted") if post.is_deleted?
  end

  def validate_reason
    case reason_name
    when "deletion"
      # You're probably looking at this line as you get this validation failure
      errors.add(:reason, "is not one of the available choices") unless is_deletion
    when "inferior"
      if parent_post.blank?
        errors.add(:parent_id, "must exist")
        return false
      end
      errors.add(:parent_id, "cannot be set to the post being flagged") if parent_post.id == post.id
    when "uploading_guidelines"
      errors.add(:reason, "cannot be used") unless post.flaggable_for_guidelines?(creator)
    when "stuck_in_progress"
      errors.add(:reason, "cannot be used") unless post.flaggable_for_stuck_in_progress?(creator)
    else
      errors.add(:reason, "is not one of the available choices") unless MAPPED_REASONS.key?(reason_name)
    end
  end

  def validate_note_required_for_reason
    return if reason_name.blank?
    reason = GayFurCity.config.flag_reasons.find { |r| r[:name].to_s == reason_name.to_s }
    if reason && reason[:require_explanation] && note.to_s.strip.blank?
      errors.add(:note, "is required for the selected reason")
    end
  end

  def update_reason
    case reason_name
    when "deletion"
      # NOOP
    when "inferior"
      return unless parent_post
      old_parent_id = post.parent_id
      post.update_column(:parent_id, parent_post.id)
      # Fix handling when parent/child is currently inverted. See #258
      if parent_post.parent_id == post.id
        parent_post.update_column(:parent_id, nil)
        post.update_has_children_flag
      end
      # Update parent flags on parent post
      parent_post.update_has_children_flag
      # Update parent flags on old parent post, if it exists
      Post.find(old_parent_id).update_has_children_flag if old_parent_id && parent_post.id != old_parent_id
      self.reason = "Inferior version/duplicate of post ##{parent_post.id}"
    else
      self.reason = MAPPED_REASONS[reason_name]
    end
  end

  def resolve!(user)
    update(is_resolved: true, updater: user)
  end

  def parent_post
    @parent_post ||= begin
      Post.where("id = ?", parent_id).first
    rescue StandardError
      nil
    end
  end

  def create_post_event
    # Deletions also create flags, but they create a deletion event instead
    PostEvent.add!(post.id, creator, :flag_created, reason: reason, post_flag_id: id) unless is_deletion
  end

  def can_see_note?(user)
    return true if user.is_staff?
    creator_id == user.id
  end

  def self.available_includes
    %i[post]
  end
end

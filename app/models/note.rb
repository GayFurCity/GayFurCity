# frozen_string_literal: true

class Note < ApplicationRecord
  attr_accessor(:html_id)

  belongs_to(:post)
  belongs_to_user(:creator, ip: true, clones: :updater)
  soft_deletable(:is_active)
  resolvable(:updater)
  has_many(:versions, -> { order("note_versions.id": :asc) }, class_name: "NoteVersion", dependent: :destroy)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  revertible do |version|
    self.x = version.x
    self.y = version.y
    self.post_id = version.post_id
    self.body = version.body
    self.width = version.width
    self.height = version.height
    self.is_active = version.is_active
  end

  validates(:creator_id, :x, :y, :width, :height, :body, presence: true)
  validate(:user_not_limited)
  validate(:post_must_exist)
  validate(:note_within_image)
  validates(:body, length: { minimum: 1, maximum: -> { AdminConfig.instance.note_max_size } }, if: :body_changed?)
  after_save(:update_post)
  after_save(:create_version)
  validate(:post_must_not_be_note_locked)

  module SearchMethods
    def post_tags_match(query, user)
      where(post_id: Post.tag_match_sql(query, user))
    end

    def query_dsl
      super
        .field(:body_matches, :body)
        .field(:is_active)
        .field(:post_id)
        .field(:ip_addr, :creator_ip_addr)
        .custom(:post_tags_match, ->(q, v, user) { q.post_tags_match(v, user) })
        .custom(:post_note_updater_id, ->(q, v) { q.where(post_id: NoteVersion.select(:post_id).where(updater_id: v.to_s.split(",").map(&:to_i))) })
        .custom(:post_note_updater_name, ->(q, v) { q.where(post_id: NoteVersion.select(:post_id).user_name_matches(:updater, v)) })
        .association(:creator)
        .association(:post)
    end
  end

  extend(SearchMethods)

  def user_not_limited
    allowed = updater.can_note_edit_with_reason
    if allowed != true
      errors.add(:base, "User #{User.throttle_reason(allowed)}.")
      false
    end
    true
  end

  def post_must_exist
    unless Post.exists?(post_id)
      errors.add(:post, "must exist")
      false
    end
  end

  def post_must_not_be_note_locked
    if is_locked?
      errors.add(:post, "is note locked")
      false
    end
  end

  def note_within_image
    return false if post.blank?
    if x < 0 || y < 0 || (x > post.image_width) || (y > post.image_height) || width < 0 || height < 0 || (x + width > post.image_width) || (y + height > post.image_height)
      errors.add(:note, "must be inside the image")
      false
    end
  end

  def is_locked?
    Post.exists?(["id = ? AND is_note_locked = ?", post_id, true])
  end

  def rescale!(x_scale, y_scale, user)
    self.x *= x_scale
    self.y *= y_scale
    self.width *= x_scale
    self.height *= y_scale
    self.updater = user
    save!
  end

  def update_post
    if saved_changes?
      post_noted_at = Note.exists?(is_active: true, post_id: post_id) ? updated_at : nil
      Post.where(id: post_id).update_all(last_noted_at: post_noted_at)
      post.reload.update_index
    end
  end

  def create_version
    return unless saved_change_to_versioned_attributes?

    Note.where(id: id).update_all("version = coalesce(version, 0) + 1")
    reload
    create_new_version(updater.id, updater_ip_addr)
  end

  def saved_change_to_versioned_attributes?
    new_record? || saved_change_to_x? || saved_change_to_y? || saved_change_to_width? || saved_change_to_height? || saved_change_to_is_active? || saved_change_to_body?
  end

  def create_new_version(updater_id, updater_ip_addr)
    versions.create(
      updater_id:      updater_id,
      updater_ip_addr: updater_ip_addr,
      post_id:         post_id,
      x:               x,
      y:               y,
      width:           width,
      height:          height,
      is_active:       is_active,
      body:            body,
      version:         version,
    )
  end

  def copy_to(new_post, user)
    new_note = dup
    new_note.post_id = new_post.id
    new_note.version = 0

    width_ratio = new_post.image_width.to_f / post.image_width
    height_ratio = new_post.image_height.to_f / post.image_height
    new_note.x = x * width_ratio
    new_note.y = y * height_ratio
    new_note.width = width * width_ratio
    new_note.height = height * height_ratio

    new_note.creator = user

    new_note.save
  end

  def self.undo_changes_by_user(vandal_id, user)
    transaction do
      note_ids = NoteVersion.where(updater_id: vandal_id).distinct.pluck(:note_id)
      NoteVersion.where(["updater_id = ?", vandal_id]).delete_all
      note_ids.each do |note_id|
        note = Note.find(note_id)
        most_recent = note.versions.last
        if most_recent
          note.revert_to!(most_recent, user)
        end
      end
    end
  end

  def self.available_includes
    %i[creator post]
  end
end

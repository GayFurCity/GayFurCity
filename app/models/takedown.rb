# frozen_string_literal: true

class Takedown < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater, optional: true)
  belongs_to_user(:updater, ip: true, optional: true)
  belongs_to_user(:approver, ip: true, optional: true)
  resolvable(:destroyer)
  before_validation(:initialize_vericode, on: :create)
  before_validation(:normalize_post_ids)
  before_validation(:strip_fields)
  validates(:email, format: { with: /\A([\s*A-Z0-9._%+-]+@[\s*A-Z0-9.-]+\.\s*[A-Z\s*]{2,15}\s*)\z/i, on: :create })
  validates(:email, length: { maximum: 250 }, presence: true)
  validates(:reason, length: { maximum: 5_000 }, presence: true)
  validates(:instructions, length: { maximum: 5_000 })
  validates(:notes, length: { maximum: 5_000 })
  validate(:can_create_takedown, on: :create)
  validate(:valid_posts_or_instructions, on: :create)
  validate(:validate_number_of_posts)
  validate(:validate_post_ids)
  after_validation(:normalize_deleted_post_ids)
  before_save(:update_post_count)

  def initialize_vericode
    self.vericode ||= Takedown.create_vericode
  end

  def strip_fields
    self.email = email&.strip
    self.source = source&.strip
  end

  def self.create_vericode
    consonants = "bcdfghjklmnpqrstvqxyz"
    vowels = "aeiou"
    pass = ""

    4.times do
      pass += consonants[rand(21), 1]
      pass += vowels[rand(5), 1]
    end

    pass += rand(100).to_s
    pass
  end

  module ValidationMethods
    def valid_posts_or_instructions
      if post_array.size <= 0 && instructions.blank?
        errors.add(:base, "You must provide post ids or instructions.")
        false
      end
    end

    def can_create_takedown
      return if creator&.is_admin?

      if IpBan.is_banned?(creator_ip_addr.to_s)
        errors.add(:base, "Something went wrong. Please email us at #{AdminConfig.instance.takedown_email} instead")
        return
      end

      takedowns_ip = Takedown.where(creator_ip_addr: creator_ip_addr, created_at: 1.day.ago..)
      if takedowns_ip.count > 5
        errors.add(:base, "You have created too many takedowns. Please email us at #{AdminConfig.instance.takedown_email} or try again later")
        return
      end

      takedowns_user = Takedown.where(creator_id: creator_id, created_at: 1.day.ago..)
      if creator_id && takedowns_user.count > 5
        errors.add(:base, "You have created too many takedowns. Please email us at #{AdminConfig.instance.takedown_email} or try again later")
      end
    end

    def validate_number_of_posts
      if post_array.size > 5_000
        errors.add(:base, "You can only have 5000 posts in a takedown.")
        return false
      end
      true
    end
  end

  module AccessMethods
    def can_edit?(user)
      user.is_admin?
    end

    def can_delete?(user)
      user.is_admin?
    end
  end

  module ModifyPostMethods
    def add_posts_by_ids!(ids, user)
      added_ids = []
      with_lock do
        self.post_ids = (post_array + matching_post_ids(ids)).uniq.join(" ")
        self.updater = user
        added_ids = post_array - post_array_was
        save!
      end
      added_ids
    end

    def add_posts_by_tags!(tag_string, user)
      new_ids = Post.tag_match_system("#{tag_string} -status:deleted").limit(1000).pluck(:id)
      add_posts_by_ids!(new_ids.join(" "), user)
    end

    def remove_posts_by_ids!(ids, user)
      with_lock do
        self.post_ids = (post_array - matching_post_ids(ids)).uniq.join(" ")
        self.updater = user
        save!
      end
    end

    def matching_post_ids(input)
      input.scan(%r{(?:https://gayfur\.city/posts/)?(\d+)}i).flatten.map(&:to_i).uniq
    end
  end

  module PostMethods
    def should_delete(id)
      del_post_array.include?(id)
    end

    def normalize_post_ids
      self.post_ids = matching_post_ids(post_ids).join(" ")
    end

    def normalize_deleted_post_ids
      posts = matching_post_ids(post_ids)
      del_posts = matching_post_ids(del_post_ids)
      del_posts &= posts # ensure that all deleted posts are also posts
      self.del_post_ids = del_posts.join(" ")
    end

    def validate_post_ids
      temp_post_ids = Post.select(:id).where(id: post_array).map { |x| x.id.to_s }
      self.post_ids = temp_post_ids.join(" ")
    end

    def del_post_array
      matching_post_ids(del_post_ids)
    end

    def actual_deleted_posts
      @actual_deleted_posts ||= Post.where(id: del_post_array)
    end

    def post_array
      matching_post_ids(post_ids)
    end

    def post_array_was
      matching_post_ids(post_ids_was)
    end

    def actual_posts
      @actual_posts ||= Post.where(id: post_array)
    end

    def actual_kept_posts
      @actual_kept_posts ||= Post.where(id: kept_post_array)
    end

    def kept_post_array
      @kept_post_array ||= post_array - del_post_array
    end

    def clear_cached_arrays
      @actual_posts = @actual_deleted_posts = @actual_kept_posts = nil
      @post_array = @del_post_array = @kept_post_array = nil
    end

    def update_post_count
      normalize_post_ids
      normalize_deleted_post_ids
      clear_cached_arrays
      self.post_count = post_array.size
    end
  end

  module ProcessMethods
    def apply_posts(posts)
      to_del = []
      posts ||= []
      posts.each do |post_id, keep|
        if keep == "1"
          to_del << post_id
        end
      end
      to_del.map!(&:to_i)
      self.del_post_ids = to_del
    end

    def process!(approver, del_reason)
      TakedownJob.perform_later(id, approver, del_reason)
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:source)
        .field(:reason)
        .field(:instructions)
        .field(:notes)
        .field(:reason_hidden)
        .field(:email)
        .field(:vericode)
        .field(:status)
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .custom(:post_id, ->(q, v) { q.where.regex(post_ids: "(^| )#{v.to_i}($| )") })
        .association(:creator)
        .association(:updater)
        .association(:approver)
    end

    def apply_order(params)
      order_with({
        status:     { "takedowns.status": :asc },
        post_count: { "takedowns.post_count": :desc },
      }, params[:order])
    end
  end

  module StatusMethods
    def completed?
      %w[approved denied partial].include?(status)
    end

    def calculated_status
      kept_count = kept_post_array.size
      deleted_count = del_post_array.size

      if kept_count == 0 # All were deleted, so it was approved
        "approved"
      elsif deleted_count == 0 # All were kept, so it was denied
        "denied"
      else # Some were kept and some were deleted, so it was partially approved
        "partial"
      end
    end
  end

  modactions(:takedown)
    .add(:delete, :destroyer, on: :destroy)
    .add(:process, :approver)

  include(PostMethods)
  include(ValidationMethods)
  include(StatusMethods)
  include(ModifyPostMethods)
  include(ProcessMethods)
  include(AccessMethods)
  extend(SearchMethods)

  def self.available_includes
    %i[approver]
  end
end

# frozen_string_literal: true

class BulkUpdateRequest < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  belongs_to_user(:approver, optional: true)
  revertible do |version|
    self.script = version.script
    self.status = version.status
    self.title = version.title
  end
  attr_accessor(:skip_forum, :should_validate)
  attr_writer(:context)

  belongs_to(:forum_topic, optional: true)
  belongs_to(:forum_post, optional: true)
  has_many(:versions, -> { order(id: :asc) }, class_name: "BulkUpdateRequestVersion", dependent: :destroy)

  validates(:script, presence: true)
  validates(:title, presence: { if: ->(rec) { rec.forum_topic_id.blank? } })
  validates(:status, format: { with: /\A(approved|rejected|pending|processing|queued|error: .*)\Z/ })
  validate(:script_formatted_correctly)
  validate(:forum_topic_id_not_invalid)
  validate(:validate_script, on: :create)
  validate(:check_validate_script, on: :update)
  validates(:reason, length: { minimum: 5, maximum: -> { AdminConfig.instance.forum_post_max_size } }, on: :create, unless: :skip_forum)
  before_validation(:normalize_text)
  after_create(:create_forum_topic)
  after_create(:create_version)
  after_update(:create_version, if: :saved_change_to_watched_attributes?)

  scope(:pending_first, -> { order(case_order(:status, [nil, "queued", "processing", "pending", "approved", "rejected"])) })
  scope(:pending, -> { where(status: "pending") })

  module SearchMethods
    def default_order
      pending_first.order(id: :desc)
    end

    def query_dsl
      super
        .field(:forum_topic_id)
        .field(:forum_post_id)
        .field(:status)
        .field(:title_matches, :title)
        .field(:script_matches, :script)
        .field(:creator_ip_addr)
        .field(:updater_ip_addr)
        .association(:creator)
        .association(:updater)
        .association(:approver)
    end

    def apply_order(params)
      order_with({
        status:      { status: :desc },
        title:       { title: :desc },
        rating:      -> { left_joins(:forum_post).order("forum_posts.percentage_score": :desc, "id": :desc) },
        rating_asc:  -> { left_joins(:forum_post).order("forum_posts.percentage_score": :asc, "id": :desc) },
        rating_desc: -> { left_joins(:forum_post).order("forum_posts.percentage_score": :desc, "id": :desc) },
        score:       -> { left_joins(:forum_post).order("forum_posts.total_score": :desc, "id": :desc) },
        score_asc:   -> { left_joins(:forum_post).order("forum_posts.total_score": :asc, "id": :desc) },
        score_desc:  -> { left_joins(:forum_post).order("forum_posts.total_score": :desc, "id": :desc) },
      }, params[:order])
    end
  end

  module ApprovalMethods
    def forum_updater
      @forum_updater ||= ForumUpdater.new(
        forum_topic,
        forum_post:     (forum_post || forum_topic.posts.first if forum_topic),
        expected_title: title,
        skip_update:    !TagRelationship::SUPPORT_HARD_CODED,
      )
    end

    def approve!(approver, update_topic: true)
      update(status: "queued", approver: approver)
      ProcessBulkUpdateRequestJob.perform_later(self, approver, update_topic)
      # forum_updater.update("The #{bulk_update_request_link} (forum ##{forum_post&.id}) has been approved by @#{approver.name}.", "APPROVED")
    rescue BulkUpdateRequestProcessor::Error, BulkUpdateRequestCommands::ProcessingError => e
      self.approver = approver
      forum_updater.update("The #{bulk_update_request_link} (forum ##{forum_post&.id}) has failed: #{e}", "FAILED") if update_topic
      errors.add(:base, e.to_s)
    end

    def process!(approver, update_topic: true)
      update(status: "processing", approver: approver)
      undos = processor.process!(approver)
      update_column(:undo_data, undos) if undos.present?
      forum_updater.update("The #{bulk_update_request_link} (forum ##{forum_post&.id}) has been approved by @#{approver.name}.", "APPROVED") if update_topic
      update(status: "approved", approver: approver)
    rescue BulkUpdateRequestProcessor::Error, BulkUpdateRequestCommands::ProcessingError => e
      forum_updater.update("The #{bulk_update_request_link} (forum ##{forum_post&.id}) has failed: #{e}", "FAILED") if update_topic
      update_columns(status: "error: #{e}")
    end

    def undo!(user = User.system)
      BulkUpdateRequestUndoJob.perform_later(self, user)
    end

    def process_undo!(user = User.system)
      raise("Nothing to undo") if undo_data.blank?

      mover = TagMover::Undo.new(undo_data, user: user, request: self)
      mover.undo!
      update_column(:undo_data, undo_data - mover.applied.as_json)
    end

    def create_forum_topic
      return if skip_forum
      if forum_topic_id
        forum_post = forum_topic.posts.create(body: "Reason: #{reason}", creator: creator)
        update(forum_post_id: forum_post.id, updater: creator)
      else
        forum_topic = ForumTopic.create(title: title, category_id: AdminConfig.instance.alias_and_implication_forum_category, original_post_attributes: { body: "Reason: #{reason}" }, creator: creator)
        forum_post = forum_topic.posts.first
        update(forum_topic_id: forum_topic.id, forum_post_id: forum_post.id, updater: creator)
      end
      forum_post.update(tag_change_request: self, allow_voting: true, updater: creator)
    end

    def reject!(rejector = User.system)
      transaction do
        update(status: "rejected", updater: rejector)
        forum_updater.update("The #{bulk_update_request_link} (forum ##{forum_post&.id}) has been rejected by @#{rejector.name}.", "REJECTED")
      end
    end

    def bulk_update_request_link
      %("bulk update request ##{id}":/bulk_update_requests/#{id})
    end
  end

  module ValidationMethods
    def script_formatted_correctly
      BulkUpdateRequestCommands.tokenize(script)
      true
    rescue StandardError => e
      errors.add(:base, e.message)
      false
    end

    def forum_topic_id_not_invalid
      if forum_topic_id && !forum_topic
        errors.add(:base, "Forum topic ID is invalid")
      end
    end

    def check_validate_script
      validate_script if should_validate
    end

    def validate_script
      processor = self.processor
      processor.validate
      if processor.errors.any?
        self.script = processor.script_with_errors
        errors.merge!(processor.errors)
      else
        self.script = processor.script_with_comments
      end

      processor.errors.empty?
    rescue BulkUpdateRequestProcessor::Error => e
      errors.add(:script, e)
    end
  end

  module VersionMethods
    def create_version
      BulkUpdateRequestVersion.queue(self, updater.resolvable(updater_ip_addr))
    end

    def saved_change_to_watched_attributes?
      saved_change_to_script? || saved_change_to_status? || saved_change_to_title?
    end
  end

  extend(SearchMethods)
  include(ApprovalMethods)
  include(ValidationMethods)
  include(VersionMethods)

  concerning(:EmbeddedText) do
    class_methods do
      def embedded_pattern
        /\[bur:(?<id>\d+)\]/m
      end
    end
  end

  def editable?(user)
    is_pending? && (creator_id == user.id || user.can_manage_aibur?)
  end

  def approvable?(user)
    return false unless is_pending? && user.can_manage_aibur?
    (creator_id != user.id || user.is_admin?) && AdminConfig.get_user(:tag_change_request_update_limit, user) >= estimate_update_count
  end

  def rejectable?(user)
    is_pending? && editable?(user)
  end

  def normalize_text
    self.script = script.downcase
  end

  def skip_forum=(value) # rubocop:disable Lint/DuplicateMethods
    @skip_forum = value.to_s.truthy?
  end

  def is_pending?
    status == "pending"
  end

  def is_approved?
    status == "approved"
  end

  def is_rejected?
    status == "rejected"
  end

  def context
    @context ||= :create
  end

  def processor(context = self.context)
    BulkUpdateRequestProcessor.new(script, forum_topic_id, context: context, creator: creator, ip_addr: creator_ip_addr, request: self)
  end

  delegate(:estimate_update_count, to: :processor)

  def self.available_includes
    %i[approver creator forum_post forum_topic]
  end
end

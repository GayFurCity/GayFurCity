# frozen_string_literal: true

class BulkUpdateRequestImport < ApplicationRecord
  belongs_to_user(:creator, ip: true, clone: :updater)
  belongs_to_user(:updater, ip: true)
  belongs_to(:forum_topic, optional: true)

  enum(:status, %i[pending processing completed failed].index_with(&:to_s))

  validate(:validate_script, unless: -> { skip_script_validation.truthy? })
  after_create(:log_create)
  after_update(:log_update, unless: -> { skip_script_validation.truthy? })
  attr_accessor(:skip_script_validation)

  module SearchMethods
    def query_dsl
      super
        .field(:status)
        .field(:forum_topic_id)
        .field(:script_matches, :script)
        .user(:creator)
        .field(:creator_ip_addr)
        .user(:updater)
        .field(:updater_ip_addr)
    end
  end

  module LogMethods
    def log_create
      ModAction.log!(creator, :bulk_update_request_import_create, self)
    end

    def log_update
      ModAction.log!(updater, :bulk_update_request_import_update, self)
    end

    def log_retry
      ModAction.log!(updater, :bulk_update_request_import_retry, self)
    end
  end

  extend(SearchMethods)
  include(LogMethods)

  def processor
    @processor ||= BulkUpdateRequestProcessor.new(script, forum_topic_id, creator: creator, ip_addr: creator_ip_addr)
  end

  def script=(value)
    @processor = nil
    super
  end

  def forum_topic_id=(value)
    @processor = nil
    super
  end

  def validate_script
    return if processor.valid?
    processor.errors.full_messages.each { |message| errors.add(:script, message) }
  end

  delegate(:script_with_comments_and_errors, to: :processor)

  def queue
    BulkUpdateRequestImportJob.perform_later(id)
  end

  def process!
    self.skip_script_validation = true
    update(status: "processing", status_message: nil)
    processor.process!(creator)
    update(status: "completed")
  rescue BulkUpdateRequestProcessor::Error, BulkUpdateRequestCommands::ProcessingError => e
    update(status: "failed", status_message: e.message)
  end

  def retry!(retrier)
    @processor = nil
    update(updater: retrier, status: "pending", status_message: nil, skip_script_validation: true)
    log_retry
    queue
  end
end

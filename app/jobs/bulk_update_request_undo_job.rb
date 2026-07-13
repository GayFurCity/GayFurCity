# frozen_string_literal: true

class BulkUpdateRequestUndoJob < ApplicationJob
  queue_as(:tags)
  sidekiq_options(lock: :until_executed, lock_args_method: :lock_args)

  def self.lock_args(args)
    [args[0].id]
  end

  def perform(bur, user)
    bur.process_undo!(user)
  end
end

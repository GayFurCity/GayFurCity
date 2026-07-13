# frozen_string_literal: true

class TagAliasUndoJob < ApplicationJob
  queue_as(:tags)

  def perform(*args)
    ta = TagAlias.find(args[0])
    ta.process_undo!(args[2], update_topic: args[1])
  end
end

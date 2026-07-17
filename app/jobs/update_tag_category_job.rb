# frozen_string_literal: true

class UpdateTagCategoryJob < ApplicationJob
  queue_as(:low)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "UpdateTagCategoryJob-#{arguments[0]}" })

  def perform(id)
    @tag = Tag.find(id)
    @tag.update_category_post_counts!
  end
end

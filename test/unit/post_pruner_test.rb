# frozen_string_literal: true

require("test_helper")

class PostPrunerTest < ActiveSupport::TestCase
  context("The post pruner") do
    setup do
      @old_post = create(:post, created_at: 8.days.ago, is_pending: true)
      @appealed_post = create(:post, is_deleted: true)
      @old_appeal = create(:post_appeal, created_at: 8.days.ago, post: @appealed_post)

      PostPruner.new.prune!
    end

    should("prune expired pending posts") do
      @old_post.reload

      assert_predicate(@old_post, :is_deleted?)
    end

    should("prune old pending appeals") do
      @old_appeal.reload

      assert_predicate(@old_appeal, :rejected?)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class ErisUpdateJobTest < ActiveSupport::TestCase
  context("ErisUpdateJob") do
    should("retry instead of raising when eris update fails") do
      post = create(:post)
      ErisProxy.stubs(:update_post).raises(ErisProxy::Error, "failed to generate thumb")

      assert_nothing_raised do
        ErisUpdateJob.perform_later(post.id)
        perform_enqueued_jobs
      end

      assert_enqueued_with(job: ErisUpdateJob, args: [post.id])
    end

    should("do nothing if the post no longer exists") do
      ErisProxy.expects(:update_post).never

      assert_nothing_raised { ErisUpdateJob.perform_now(-1) }
    end
  end
end

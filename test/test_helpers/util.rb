# frozen_string_literal: true

module TestHelpers
  module Util
    extend(ActiveSupport::Concern)
    include(ActiveJob::TestHelper)

    class_methods do
      # The post index is only ever created/emptied once, at test process boot (see test_helper.rb) -
      # it does NOT get a fresh, isolated copy per test the way Postgres does via transactional
      # rollback. Any test that creates posts leaves them indexed for every test that runs after it
      # in the same process. Call this in any context whose assertions depend on exact post counts or
      # search results, so it can't be corrupted by whatever ran before it.
      def resets_post_index!
        setup { reset_post_index }
      end
    end

    # perform_enqueued_jobs(&block) runs each job the instant it's enqueued - including mid-callback,
    # e.g. from a before_save (Tag#update_category -> UpdateTagCategoryJob). That's a problem: the
    # job's own fresh find sees the record as it was before the triggering save's UPDATE reached the
    # database, since the save hasn't finished yet. Sidekiq avoided this via Sidekiq.transactional_push!
    # (see old sidekiq.rb initializer), which defers a job's actual execution until the enclosing
    # transaction/savepoint completes, using the after_commit_everywhere gem - the exact same gem this
    # codebase already depends on for other post-commit hooks. Rails' plain :test adapter has no
    # equivalent, so this reimplements it: intercept the adapter's "execute now" step and defer each
    # job through AfterCommitEverywhere.after_commit instead of running it inline immediately. This
    # preserves perform_enqueued_jobs' interleaved run-as-enqueued ordering (unlike collecting jobs and
    # running them all only once the whole block finishes, which breaks callers enqueueing more than one
    # job per block where the second depends on the first's job having already run), while still
    # guaranteeing a job never observes its own triggering write mid-flight.
    def with_inline_jobs(&)
      adapter = ActiveJob::Base.queue_adapter
      adapter.singleton_class.prepend(DeferredInlinePerform) unless adapter.is_a?(DeferredInlinePerform)
      perform_enqueued_jobs(&)
    end

    module DeferredInlinePerform
      private

      def perform_or_enqueue(perform, job, job_data)
        return super unless perform
        performed_jobs << job_data
        AfterCommitEverywhere.after_commit { ActiveJob::Base.execute(job.serialize) }
      end
    end

    def reset_post_index
      # Post/PostVersion default to skipping indexing entirely in test (see DocumentStore::Model) -
      # opt this test back in for its duration, since it's asserting on search/index state.
      Post.any_instance.stubs(:skip_index_update).returns(false)
      PostVersion.any_instance.stubs(:skip_index_update).returns(false)

      # This seems slightly faster than deleting and recreating the index
      Post.document_store.delete_by_query(query: "*", body: {})
      Post.document_store.refresh_index!
    end

    def mock_request(remote_ip: "127.0.0.1", host: "localhost", user_agent: "Firefox", session_id: "1234", parameters: {})
      cookie_jar = mock
      cookie_jar.stubs(:encrypted).returns({})
      request = mock
      request.stubs(:host).returns(host)
      request.stubs(:remote_ip).returns(remote_ip)
      request.stubs(:user_agent).returns(user_agent)
      request.stubs(:authorization).returns(nil)
      request.stubs(:session).returns(session_id: session_id)
      request.stubs(:parameters).returns(parameters)
      request.stubs(:delete).with(:user_id).returns(nil)
      request.stubs(:delete).with(:last_authenticated_at).returns(nil)
      request.stubs(:cookie_jar).returns(cookie_jar)
      request
    end

    def random
      SecureRandom.hex(6)
    end
  end
end

# frozen_string_literal: true

module TestHelpers
  module Util
    extend(ActiveSupport::Concern)

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

    def with_inline_jobs(&)
      Sidekiq::Testing.inline!(&)
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

module TestHelpers
  module Util
    extend(ActiveSupport::Concern)

    def with_inline_jobs(&)
      Sidekiq::Testing.inline!(&)
    end

    def reset_post_index
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

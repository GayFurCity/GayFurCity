# frozen_string_literal: true

require("test_helper")

class ErisProxyTest < ActiveSupport::TestCase
  setup do
    GayFurCity.config.stubs(:eris_server).returns("http://eris:5588")
    clear_eris_keys
  end

  teardown do
    clear_eris_keys
  end

  def clear_eris_keys
    [ErisProxy::CIRCUIT_FAILURES_KEY, ErisProxy::CIRCUIT_OPEN_KEY, ErisProxy::ANON_LOCKDOWN_KEY, ErisProxy::CONCURRENT_KEY].each { |key| Cache.redis.del(key) }
  end

  context("query_post") do
    should("query eris by post id") do
      post = create(:post)
      stub_request(:post, "http://eris:5588/query")
        .with(body: { post_id: post.id }.to_json)
        .to_return(status: 200, body: [{ post_id: post.id, score: 95.5, hash: "abc" }].to_json)

      matches = ErisProxy.query_post(post.id.to_s, nil)

      assert_equal([post], matches.pluck("post"))
      assert_in_delta(95.5, matches[0]["score"])
    end

    should("not query eris for invalid ids") do
      assert_equal([], ErisProxy.query_post("0", nil))
      assert_not_requested(:post, "http://eris:5588/query")
    end

    should("return nothing for an unindexed post") do
      stub_request(:post, "http://eris:5588/query").to_return(status: 404, body: { error: "not_indexed" }.to_json)

      assert_equal([], ErisProxy.query_post(1, nil))
    end
  end

  context("results") do
    should("drop matches below the cutoff and matches for missing posts") do
      post = create(:post)
      stub_request(:post, "http://eris:5588/query").to_return(status: 200, body: [
        { post_id: post.id, score: 90 },
        { post_id: post.id + 1000, score: 90 },
        { post_id: post.id, score: 10 },
      ].to_json)

      matches = ErisProxy.query_hash("abc", 60)

      assert_equal([[post.id, 90]], matches.map { |x| [x["post_id"], x["score"]] })
    end
  end

  context("make_request") do
    should("send the token when one is configured") do
      GayFurCity.config.stubs(:eris_token).returns("secret")
      stub_request(:get, "http://eris:5588/status").with(headers: { "Authorization" => "Bearer secret" }).to_return(status: 200)

      assert_equal(200, ErisProxy.make_request("/status", :get).status)
    end
  end

  context("circuit breaker") do
    setup do
      GayFurCity.config.stubs(:eris_circuit_failure_threshold).returns(2)
    end

    should("open after repeated failures and lock out anonymous users") do
      stub_request(:post, "http://eris:5588/query").to_return(status: 500)

      2.times { ErisProxy.query_hash("abc", nil) }

      assert_predicate(ErisProxy, :anon_lockdown?)
      assert_raises(ErisProxy::CircuitOpenError) { ErisProxy.query_hash("abc", nil) }
    end

    should("not count client errors as failures") do
      stub_request(:post, "http://eris:5588/query").to_return(status: 400)

      3.times { ErisProxy.query_hash("abc", nil) }

      assert_not(ErisProxy.anon_lockdown?)
    end

    should("count connection failures") do
      stub_request(:post, "http://eris:5588/query").to_raise(Faraday::ConnectionFailed.new("refused"))

      2.times { assert_raises(ErisProxy::Error) { ErisProxy.query_hash("abc", nil) } }

      assert_raises(ErisProxy::CircuitOpenError) { ErisProxy.query_hash("abc", nil) }
    end
  end

  context("concurrency limit") do
    should("reject queries over the limit") do
      GayFurCity.config.stubs(:eris_max_concurrent_queries).returns(1)
      Cache.redis.set(ErisProxy::CONCURRENT_KEY, 1)

      assert_raises(ErisProxy::BusyError) { ErisProxy.query_hash("abc", nil) }
      assert_equal("1", Cache.redis.get(ErisProxy::CONCURRENT_KEY))
    end

    should("release the slot after a query") do
      stub_request(:post, "http://eris:5588/query").to_return(status: 200, body: "[]")

      ErisProxy.query_hash("abc", nil)

      assert_equal("0", Cache.redis.get(ErisProxy::CONCURRENT_KEY))
    end
  end
end

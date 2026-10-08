# frozen_string_literal: true

require("test_helper")

module Posts
  class ErisControllerTest < ActionDispatch::IntegrationTest
    context("The eris controller") do
      setup do
        ErisProxy.stubs(:endpoint).returns("http://eris:5588")
        @user = create(:user)
        @posts = create_list(:post, 2, uploader: @user)
      end

      context("show action") do
        context("with a url parameter") do
          setup do
            create(:upload_whitelist, pattern: "*google.com")
            @url = "https://google.com"
            @params = { url: @url }
            @mocked_response = [{
              "post"    => @posts[0],
              "post_id" => @posts[0].id,
              "score"   => 1,
            }]
          end

          should("render a response") do
            ErisProxy.expects(:query_url).with(@user, @url, nil).returns(@mocked_response)
            get_auth(posts_eris_path, @user, params: @params)

            assert_select("#post_#{@posts[0].id}")
          end
        end

        context("with a post_id parameter") do
          setup do
            @params = { post_id: @posts[0].id }
            @url = @posts[0].preview_file_url(@user)
            @mocked_response = [{
              "post"    => @posts[0],
              "post_id" => @posts[0].id,
              "score"   => 1,
            }]
          end

          should("redirect to eris") do
            ErisProxy.expects(:query_post).with(@posts[0].id.to_s, nil).returns(@mocked_response)
            get_auth(posts_eris_path, @user, params: @params)

            assert_select("#post_#{@posts[0].id}")
          end
        end

        context("with matches") do
          setup do
            json = @posts.map { |x| { "post_id" => x.id, "score" => 1 } }.to_json
            @params = { matches: json }
          end

          should("render with matches") do
            get_auth(posts_eris_path, @user, params: @params)

            assert_response(:success)
          end
        end

        context("with invalid input") do
          should("reject a non numeric post id") do
            ErisProxy.expects(:query_post).never
            get_auth(posts_eris_path, @user, params: { post_id: "abc" })

            assert_response(:bad_request)
            assert_select("span.error", text: "Please enter a valid post ID.")
          end

          should("reject a non hex hash") do
            ErisProxy.expects(:query_hash).never
            get_auth(posts_eris_path, @user, params: { hash: "zzz", format: :json })

            assert_response(:bad_request)
          end

          should("reject a url that isn't http or https") do
            ErisProxy.expects(:query_url).never
            get_auth(posts_eris_path, @user, params: { url: "ftp://example.com/a.png" })

            assert_response(:bad_request)
          end
        end

        context("when eris fails") do
          should("return 429 when busy") do
            ErisProxy.stubs(:query_post).raises(ErisProxy::BusyError, "busy")
            get_auth(posts_eris_path, @user, params: { post_id: @posts[0].id })

            assert_response(:too_many_requests)
            assert_select("span.error", text: "busy")
          end

          should("return 503 when unavailable") do
            ErisProxy.stubs(:query_post).raises(ErisProxy::CircuitOpenError, "down")
            get_auth(posts_eris_path, @user, params: { post_id: @posts[0].id, format: :json })

            assert_response(:service_unavailable)
          end

          should("return 422 when the url can't be downloaded") do
            create(:upload_whitelist, pattern: "*google.com")
            ErisProxy.stubs(:query_url).raises(Downloads::File::Error, "HTTP error code: 404 Not Found")
            get_auth(posts_eris_path, @user, params: { url: "https://google.com" })

            assert_response(:unprocessable_content)
          end
        end

        context("throttling") do
          setup do
            GayFurCity.config.stubs(:disable_throttles).returns(false)
            ErisProxy.stubs(:query_post).returns([])
            ErisProxy.stubs(:query_url).returns([])
            create(:upload_whitelist, pattern: "*google.com")
            # logging in checks its own limit
            RateLimiter.stubs(:check_limit).returns(false)
          end

          should("use the light limits for post id searches") do
            RateLimiter.expects(:check_limit).with("eris:light:127.0.0.1", 10, 10.seconds).returns(false)
            RateLimiter.expects(:check_limit).with("eris:light:user:#{@user.id}", 10, 10.seconds).returns(false)
            get_auth(posts_eris_path, @user, params: { post_id: @posts[0].id })

            assert_response(:success)
          end

          should("use the heavy limits for url searches") do
            RateLimiter.expects(:check_limit).with("eris:heavy:127.0.0.1", 6, 10.seconds).returns(false)
            RateLimiter.expects(:check_limit).with("eris:heavy:user:#{@user.id}", 6, 10.seconds).returns(false)
            get_auth(posts_eris_path, @user, params: { url: "https://google.com" })

            assert_response(:success)
          end

          should("use the anonymous limits for anonymous users") do
            RateLimiter.expects(:check_limit).with("eris:light:anon:127.0.0.1", 10, 10.seconds).returns(false)
            get(posts_eris_path, params: { post_id: @posts[0].id })

            assert_response(:success)
          end

          should("throttle once the limit is hit") do
            RateLimiter.unstub(:check_limit)
            11.times { get_auth(posts_eris_path, @user, params: { post_id: @posts[0].id }) }

            assert_response(:too_many_requests)
          end

          should("block anonymous users during a lockdown") do
            ErisProxy.stubs(:anon_lockdown?).returns(true)
            get(posts_eris_path, params: { post_id: @posts[0].id })

            assert_response(:too_many_requests)
          end

          should("not throttle trusted users") do
            trusted = create(:trusted_user)
            RateLimiter.expects(:check_limit).with { |key, *| key.start_with?("eris:") }.never
            get_auth(posts_eris_path, trusted, params: { post_id: @posts[0].id })

            assert_response(:success)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(posts_eris_path)
          end
        end
      end
    end
  end
end

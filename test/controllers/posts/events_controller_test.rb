# frozen_string_literal: true

require("test_helper")

module Posts
  class EventsControllerTest < ActionDispatch::IntegrationTest
    context("The post events controller") do
      setup do
        travel_to(2.weeks.ago) do
          @user1 = create(:user)
          @user2 = create(:user)
          @user3 = create(:user)
          @janitor = create(:janitor_user)
        end

        @post1 = create(:post, uploader: @user1)
        create(:post_flag, post: @post1, creator: @user1)

        @post2 = create(:post, uploader: @user2)
        create(:post_flag, post: @post2, creator: @user2)
        @post3 = create(:post, uploader: @user2)
        create(:post_flag, post: @post3, creator: @user2)
      end

      context("index action") do
        should("render") do
          get_auth(post_events_path, @user1)

          assert_response(:ok)
        end

        context("searching") do
          should("only return your own flags as a normal  user") do
            get_auth(post_events_path(search: { creator_id: @user1.id }), @user1)

            assert_select("table tbody tr", 1)
            get_auth(post_events_path(search: { creator_id: @user1.id }), @user2)

            assert_select("table tbody tr", 0)
          end

          should("hide the creator for flags") do
            get_auth(post_events_path(search: { action: "flag_created" }), @user1)

            assert_select("table tbody tr", 3)
            assert_select("table tbody tr", { count: 2, text: /hidden/ })
            get_auth(post_events_path(search: { action: "flag_created" }), @user3)

            assert_select("table tbody tr", { count: 3, text: /hidden/ })
          end

          should("show everything for janitors") do
            get_auth(post_events_path(search: { creator_id: @user2.id }), @janitor)

            assert_select("table tbody tr", 2)
            get_auth(post_events_path(search: { action: "flag_created" }), @janitor)

            assert_select("table tbody tr", { count: 0, text: /hidden/ })
          end
        end

        context("flag_created event") do
          context("for the creator of a flag") do
            setup do
              get_auth(post_events_path, @user1, params: { format: :json })
              @flag_actions = response.parsed_body.select { |e| e["action"] == "flag_created" }
            end

            should("expose themselves as the flagger") do
              assert_equal([nil, nil, @user1.id], @flag_actions.pluck("creator_id"))
            end
          end

          context("for a normal user") do
            should("hide all flaggers") do
              get_auth(post_events_path, @user3, params: { format: :json })
              @json = response.parsed_body
              @flag_actions = response.parsed_body.select { |e| e["action"] == "flag_created" }

              assert_equal([nil, nil, nil], @flag_actions.pluck("creator_id"))
            end

            should("return no flag_created when searching by creator") do
              get_auth(post_events_path, @user3, params: { search: { creator_id: @user1.id }, format: :json })

              assert_predicate(response.parsed_body, :none?)
            end
          end

          context("for janitors") do
            setup do
              get_auth(post_events_path, @janitor, params: { format: :json })
              @json = response.parsed_body
              @flag_actions = response.parsed_body.select { |e| e["action"] == "flag_created" }
            end

            should("show all flaggers") do
              assert_equal([@user2.id, @user2.id, @user1.id], @flag_actions.pluck("creator_id"))
            end
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(post_events_path, user) }
        end

        context("search parameters") do
          subject { post_events_path }
          setup do
            PostEvent.delete_all
            @creator = create(:user)
            @admin = create(:admin_user)
            @post = create(:post)
            @post.delete!(@creator.resolvable("127.0.0.2"), "foo")
            @post_event = @post.events.last
          end

          assert_search_param(:post_id, -> { @post.id }, -> { [@post_event] })
          assert_search_param(:action, "deleted", -> { [@post_event] })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@post_event] })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@post_event] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@post_event] }, -> { @admin })
          assert_shared_search_params(-> { [@post_event] }, nil, %i[id created_at])
        end
      end
    end
  end
end

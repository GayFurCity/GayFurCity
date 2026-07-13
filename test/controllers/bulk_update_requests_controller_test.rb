# frozen_string_literal: true

require("test_helper")

class BulkUpdateRequestsControllerTest < ActionDispatch::IntegrationTest
  context("BulkUpdateRequestsController") do
    setup do
      @user = create(:user)
      @admin = create(:admin_user)
    end

    context("new action") do
      should("render") do
        get_auth(new_bulk_update_request_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(new_bulk_update_request_path)
        end
      end
    end

    context("edit action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
      end

      should("render") do
        get_auth(edit_bulk_update_request_path(@bulk_update_request), @user)

        assert_response(:success)
      end

      context("access control") do
        setup { Config.any_instance.stubs(:bur_entry_limit).returns({ User::Levels::ANONYMOUS => 1 }) }

        asserts do
          access.gte(User::Levels::MEMBER).get { |user| edit_bulk_update_request_path(create(:bulk_update_request, creator: user, skip_forum: true)) }
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_bulk_update_request_path(@bulk_update_request) }
        end
      end
    end

    context("create action") do
      should("work") do
        assert_difference("BulkUpdateRequest.count", 1) do
          post_auth(bulk_update_requests_path, @user, params: { bulk_update_request: { script: "alias aaa -> bbb", title: "xxx", reason: "xxxxx" } })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(bulk_update_requests_path).params { { bulk_update_request: { script: "alias aaa -> bbb", title: "xxx", reason: "xxxxx" } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(bulk_update_requests_path).params { { bulk_update_request: { script: "alias aaa -> bbb", title: "xxx", reason: "xxxxx" } } }
        end
      end
    end

    context("update action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
      end

      should("work") do
        create(:tag, name: "zzz")
        put_auth(bulk_update_request_path(@bulk_update_request.id), @user, params: { bulk_update_request: { script: "alias zzz -> 222" } })
        @bulk_update_request.reload

        assert_equal("alias zzz -> 222", @bulk_update_request.script)
      end

      context("access control") do
        setup { Config.any_instance.stubs(:bur_entry_limit).returns({ User::Levels::ANONYMOUS => 1 }) }

        asserts do
          access.gte(User::Levels::MEMBER).put { |user| bulk_update_request_path(create(:bulk_update_request, creator: user, skip_forum: true)) }.params { { bulk_update_request: { script: "alias xxx -> 333" } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { |user| bulk_update_request_path(create(:bulk_update_request, creator: user, skip_forum: true)) }.params { { bulk_update_request: { script: "alias xxx -> 333" } } }
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).put { bulk_update_request_path(@bulk_update_request) }.params { { bulk_update_request: { script: "alias xxx -> 333" } } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { bulk_update_request_path(@bulk_update_request) }.params { { bulk_update_request: { script: "alias xxx -> 333" } } }
        end
      end
    end

    context("index action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
      end

      should("render") do
        get(bulk_update_requests_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(bulk_update_requests_path)
          access.gte(User::Levels::ANONYMOUS).json.get(bulk_update_requests_path)
        end
      end

      context("search parameters") do
        subject { bulk_update_requests_path }
        setup do
          BulkUpdateRequestVersion.delete_all
          BulkUpdateRequest.delete_all
          @creator = create(:user)
          @updater = create(:user)
          @approver = create(:user)
          @admin = create(:admin_user)
          @forum_topic = create(:forum_topic, creator: @creator)
          @forum_post = @forum_topic.posts.first
          @bulk_update_request = create(:bulk_update_request, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", approver: @approver, status: "approved", title: "foo", script: "alias bar -> baz", forum_topic: @forum_topic, forum_post: @forum_post, skip_forum: true)
        end

        asserts do
          search(:forum_topic_id).value { @forum_topic.id }.records { [@bulk_update_request] }
          search(:forum_post_id).value { @forum_post.id }.records { [@bulk_update_request] }
          search(:status, "approved").records { [@bulk_update_request] }
          search(:title_matches, "foo").records { [@bulk_update_request] }
          search(:script_matches, "bar").records { [@bulk_update_request] }
          search(:creator_ip_addr, "127.0.0.2").records { [@bulk_update_request] }.user { @admin }
          search(:updater_ip_addr, "127.0.0.3").records { [@bulk_update_request] }.user { @admin }
          search(:creator_id).value { @creator.id }.records { [@bulk_update_request] }
          search(:creator_name).value { @creator.name }.records { [@bulk_update_request] }
          search(:updater_id).value { @updater.id }.records { [@bulk_update_request] }
          search(:updater_name).value { @updater.name }.records { [@bulk_update_request] }
          search(:approver_id).value { @approver.id }.records { [@bulk_update_request] }
          search(:approver_name).value { @approver.name }.records { [@bulk_update_request] }
          search.shared.records { [@bulk_update_request] }
        end
      end
    end

    context("destroy action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
      end

      context("for the creator") do
        should("succeed") do
          delete_auth(bulk_update_request_path(@bulk_update_request), @user)
          @bulk_update_request.reload

          assert_equal("rejected", @bulk_update_request.status)
        end
      end

      context("for another member") do
        setup do
          @another_user = create(:user)
        end

        should("fail") do
          assert_difference("BulkUpdateRequest.count", 0) do
            delete_auth(bulk_update_request_path(@bulk_update_request), @another_user)
          end
        end
      end

      context("for an admin") do
        should("succeed") do
          delete_auth(bulk_update_request_path(@bulk_update_request), @admin)
          @bulk_update_request.reload

          assert_equal("rejected", @bulk_update_request.status)
        end
      end

      context("access control") do
        setup { Config.any_instance.stubs(:bur_entry_limit).returns({ User::Levels::ANONYMOUS => 1 }) }

        asserts do
          access.gte(User::Levels::MEMBER).delete { |user| bulk_update_request_path(create(:bulk_update_request, creator: user, skip_forum: true)) }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.delete { |user| bulk_update_request_path(create(:bulk_update_request, creator: user, skip_forum: true)) }.success(:no_content)
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { bulk_update_request_path(@bulk_update_request) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { bulk_update_request_path(@bulk_update_request) }.success(:no_content)
        end
      end
    end

    context("approve action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
      end

      context("for a member") do
        should("fail") do
          post_auth(approve_bulk_update_request_path(@bulk_update_request), @user, params: { format: :json })

          assert_response(:forbidden)
          @bulk_update_request.reload

          assert_equal("pending", @bulk_update_request.status)
        end
      end

      context("for an admin") do
        should("succeed") do
          post_auth(approve_bulk_update_request_path(@bulk_update_request), @admin, params: { format: :json })

          assert_response(:success)
          @bulk_update_request.reload

          assert_equal("queued", @bulk_update_request.status)
          perform_enqueued_jobs(only: ProcessBulkUpdateRequestJob)
          @bulk_update_request.reload

          assert_equal("approved", @bulk_update_request.status)
        end

        should("not succeed if its estimated count is greater than allowed") do
          Config.stubs(:get_user).with(:tag_change_request_update_limit, @admin).returns(1)
          create_list(:post, 2, tag_string: "aaa")
          post_auth(approve_bulk_update_request_path(@bulk_update_request), @admin, params: { format: :json })

          assert_response(:forbidden)
          @bulk_update_request.reload

          assert_equal("pending", @bulk_update_request.status)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).post { approve_bulk_update_request_path(@bulk_update_request) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.post { approve_bulk_update_request_path(@bulk_update_request) }
        end
      end
    end

    context("revert action") do
      setup do
        @bulk_update_request = create(:bulk_update_request, creator: @user)
        @bulk_update_request.update_with(@user, script: "alias foo -> bar")
      end

      should("revert to a previous version") do
        version = @bulk_update_request.versions.first

        assert_match(/\Aalias aaa -> bbb/, version.script)
        put_auth(revert_bulk_update_request_path(@bulk_update_request), @user, params: { version_id: version.id })

        assert_match(/\Aalias aaa -> bbb/, @bulk_update_request.reload.script)
      end

      should("not allow reverting to a previous version of another bulk_update_request") do
        @bulk_update_request2 = create(:bulk_update_request)
        put_auth(revert_bulk_update_request_path(@bulk_update_request), @user, params: { version_id: @bulk_update_request2.versions.first.id })
        @bulk_update_request.reload

        assert_not_equal(@bulk_update_request.title, @bulk_update_request2.title)
        assert_response(:missing)
      end

      context("access control") do
        setup { Config.any_instance.stubs(:bur_entry_limit).returns({ User::Levels::ANONYMOUS => 1 }) }

        asserts do
          access do |builder|
            builder.gte(User::Levels::MEMBER).put do |user|
              bur = create(:bulk_update_request, creator: user, skip_forum: true)
              bur.update_with(user, script: "alias foo -> bar")
              revert_bulk_update_request_path(bur)
            end.params { { version_id: BulkUpdateRequest.last.versions.first.id } }.success(:redirect)
          end
          access do |builder|
            builder.gte(User::Levels::MEMBER).json.put do |user|
              bur = create(:bulk_update_request, creator: user, skip_forum: true)
              bur.update_with(user, script: "alias foo -> bar")
              revert_bulk_update_request_path(bur)
            end.params { { version_id: BulkUpdateRequest.last.versions.first.id } }
          end
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).put { revert_bulk_update_request_path(@bulk_update_request) }.params { { version_id: @bulk_update_request.versions.first.id } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { revert_bulk_update_request_path(@bulk_update_request) }.params { { version_id: @bulk_update_request.versions.first.id } }
        end
      end
    end
  end
end

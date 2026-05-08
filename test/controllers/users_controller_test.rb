# frozen_string_literal: true

require("test_helper")

class UsersControllerTest < ActionDispatch::IntegrationTest
  context("The users controller") do
    setup do
      @user = create(:user)
    end

    context("index action") do
      should("list all users") do
        get(users_path)
        assert_response(:success)
      end

      should("not redirect for /users?name=<name> if invalid") do
        get(users_path, params: { name: "some_name" })
        assert_response(:not_found)
      end

      should("redirect for /users?name=<name> if valid") do
        get(users_path, params: { name: @user.name })
        assert_redirected_to(user_path(@user))
      end

      should("list all users (with search)") do
        get(users_path, params: { search: { name_matches: @user.name } })
        assert_response(:success)
      end

      should("list all users (with blank search parameters)") do
        get(users_path, params: { search: { level: "", name: "test" } })
        assert_redirected_to(users_path(search: { name: "test" }))
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(users_path, user) }
      end

      context("search parameters") do
        subject { users_path }
        setup do
          ApplicationRecord.connection.execute("TRUNCATE users CASCADE")
          @user = create(:user, email: "foo@example.com", name: "bar", last_ip_addr: "127.0.0.2", profile_about: "baz")
          @admin = create(:admin_user, can_approve_posts: true, unrestricted_uploads: true, can_manage_aibur: true)
          @post = create(:post, uploader: @user)
          @user.update_columns(avatar_id: @post.id)
        end

        assert_search_param(:level, User::Levels::MEMBER, -> { [@user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:avatar_id, -> { @post.id }, -> { [@user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:email_matches, "foo@example.com", -> { [@user] }, -> { @admin }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:name_matches, "bar", -> { [@user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@user] }, -> { @admin }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:about_me, "baz", -> { [@user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:min_level, User::Levels::MEMBER, -> { [@admin, @user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:max_level, User::Levels::MEMBER, -> { [@user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:can_approve_posts, "true", -> { [@admin] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:unrestricted_uploads, "true", -> { [@admin] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_search_param(:can_manage_aibur, "true", -> { [@admin] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
        assert_shared_search_params(-> { [@admin, @user] }, -> { @user }, ignore: %w[updated_at last_logged_in_at])
      end
    end

    context("show action") do
      setup do
        # flesh out profile to get more test coverage of user presenter.
        create(:post, uploader: @user, tag_string: "fav:#{@user.name}")
      end

      should("render") do
        get(user_path(@user))
        assert_response(:success)
      end

      should("show hidden attributes to the owner") do
        get_auth(user_path(@user), @user, params: { format: :json })
        json = response.parsed_body

        assert_response(:success)
        assert_not_nil(json["last_logged_in_at"])
      end

      should("not show hidden attributes to others") do
        @another = create(:user)

        get_auth(user_path(@another), @user, params: { format: :json })
        json = response.parsed_body

        assert_response(:success)
        assert_nil(json["last_logged_in_at"])
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(user_path(@user), user) }
      end
    end

    context("new action") do
      setup do
        GayFurCity.config.stubs(:recaptcha_enabled).returns(false)
      end

      should("render") do
        get(new_user_path)
        assert_response(:success)
      end
    end

    context("create action") do
      should("create a user") do
        assert_difference(-> { User.count }, 1) do
          post(users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" } })
        end
        created_user = User.find(session[:user_id])
        assert_equal("xxx", created_user.name)
        assert_equal(Config.instance.records_per_page, created_user.per_page)
        assert_not_nil(created_user.last_ip_addr)
        assert_equal(true, created_user.user_events.user_creation.exists?)
      end

      context("with sockpuppet validation enabled") do
        setup do
          Config.any_instance.stubs(:enable_sock_puppet_validation).returns(true)
          @user.update_columns(last_ip_addr: "127.0.0.1")
        end

        should("not allow registering multiple accounts with the same IP") do
          assert_difference("User.count", 0) do
            post(users_path, params: { user: { name: "dupe", password: "xxxxx1", password_confirmation: "xxxxx1" } })
          end
        end
      end

      context("with a duplicate username") do
        setup do
          create(:user, name: "test123")
        end

        should("prevent creation") do
          assert_no_difference(-> { User.count }) do
            post(users_path, params: { user: { name: "TEst123", password: "xxxxx1", password_confirmation: "xxxxx1" } })
            assert_match(/Name already exists/, flash[:notice])
          end
        end
      end

      context("with email validation") do
        setup do
          Config.any_instance.stubs(:enable_email_verification).returns(true)
        end

        should("reject invalid emails") do
          assert_no_difference(-> { User.count }) do
            post(users_path, params: { user: { name: "test", password: "xxxxxx", password_confirmation: "xxxxxx" } })
            assert_match(/Email can't be blank/, flash[:notice])
            post(users_path, params: { user: { name: "test", password: "xxxxxx", password_confirmation: "xxxxxx", email: "invalid" } })
            assert_match(/Email is invalid/, flash[:notice])
          end
        end

        should("reject duplicate emails") do
          create(:user, email: "valid@gayfur.city")

          assert_no_difference(-> { User.count }) do
            post(users_path, params: { user: { name: "test2", password: "xxxxxx", password_confirmation: "xxxxxx", email: "VaLid@gayfur.city" } })
            assert_match(/Email has already been taken/, flash[:notice])
          end
        end
      end
    end

    context("edit action") do
      setup do
        @user = create(:user)
      end

      should("render") do
        get_auth(edit_users_path, @user)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| get_auth(edit_users_path, user) }
      end
    end

    context("update action") do
      setup do
        @user = create(:user)
      end

      should("update a user") do
        post_auth(update_users_path, @user, params: { user: { favorite_tags: "xyz" } })
        @user.reload
        assert_equal("xyz", @user.favorite_tags)
      end

      context("changing the level") do
        setup do
          @cuser = create(:user)
        end

        should("not work") do
          post_auth(update_users_path, @cuser, params: { user: { level: User::Levels::MODERATOR } })
          @user.reload
          assert_equal(User::Levels::MEMBER, @user.level)
        end
      end

      context("for a user with blank email") do
        setup do
          @user = create(:user, email: "")
          Config.any_instance.stubs(:enable_email_verification).returns(true)
        end

        should("force them to update their email") do
          post_auth(update_users_path, @user, params: { user: { comment_threshold: "-100" } })
          assert_match(/Email can't be blank/, flash[:notice])
        end
      end

      should("change password") do
        post_auth(update_users_path, @user, params: { user: { old_password: "password", password: "password2", password_confirmation: "password2" } })
        @user.reload
        assert_equal(true, @user.bcrypt_password.is_password?("password2"))
        assert_equal(true, @user.user_events.password_change.exists?)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| post_auth(update_users_path, user, params: { user: { favorite_tags: "xyz" } }) }
      end
    end

    context("custom css") do
      should("return the correct styling") do
        @user.update_columns(custom_style: "body { display:none; }")
        get_auth(custom_style_users_path(format: :css), @user)
        assert_response(:success)
        assert_equal("body { display:none !important; }", @response.body.strip)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, anonymous_response: :forbidden) { |user| get_auth(custom_style_users_path(format: :css), user) }
      end
    end

    context("unban action") do
      should("work") do
        mod = create(:moderator_user)
        @user.ban!(mod)
        assert_equal(true, @user.reload.is_banned?)
        assert_difference({ "Ban.count" => 0, "ModAction.count" => 1 }) do
          put_auth(unban_user_path(@user), mod)
          assert_redirected_to(user_path(@user))
        end
        assert_equal(false, @user.reload.is_banned?)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(unban_user_path(create(:banned_user)), user) }
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  context("The api keys controller") do
    setup do
      @user = create(:user)
      @api_key = create(:api_key, user: @user)
    end

    context("index action") do
      should("let a user see their own API keys") do
        get_auth(user_api_keys_path(@user), @user)

        assert_response(:success)
        assert_select("#api-key-#{@api_key.id}", count: 1)
      end

      should("not let a user see API keys belonging to other users") do
        get_auth(user_api_keys_path(@user), create(:user))

        assert_response(:success)
        assert_select("#api-key-#{@api_key.id}", count: 0)
      end

      should("let the owner see all API keys") do
        get_auth(user_api_keys_path(@user), create(:owner_user))

        assert_response(:success)
        assert_select("#api-key-#{@api_key.id}", count: 1)
      end

      should("not return the key in the API") do
        get_auth(user_api_keys_path(@user), @user, as: :json)

        assert_response(:success)
        assert_nil(response.parsed_body.first["key"])
      end

      should("redirect to the confirm password page if the user hasn't recently authenticated") do
        post(session_path, params: { session: { name: @user.name, password: @user.password } })
        travel_to(2.hours.from_now) do
          get(user_api_keys_path(@user))
        end

        assert_redirected_to(confirm_password_session_path(url: user_api_keys_path(@user)))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get { user_api_keys_path(@user) }
        end
      end
    end

    context("new action") do
      should("render for a Member user") do
        get_auth(new_user_api_key_path(@user), @user)

        assert_response(:success)
      end

      should("fail for an Anonymous user") do
        get(new_user_api_key_path(@user))

        assert_redirected_to(new_session_path(url: new_user_api_key_path(@user)))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get { new_user_api_key_path(@user) }
        end
      end
    end

    context("create action") do
      should("create a new API key") do
        post_auth(user_api_keys_path(@user), @user, params: { api_key: { name: "blah" } })

        assert_redirected_to(user_api_keys_path(@user.id))
        assert_equal("blah", @user.api_keys.last.name)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post { |user| user_api_keys_path(user) }.params({ api_key: { name: "blah" }}).success(:redirect)
          access.gte(User::Levels::REJECTED).json.post { |user| user_api_keys_path(user) }.params({ api_key: { name: "blah" }})
        end
      end
    end

    context("edit action") do
      should("render for the API key owner") do
        get_auth(edit_api_key_path(@api_key), @user)

        assert_response(:success)
      end

      should("fail for someone else") do
        get_auth(edit_api_key_path(@api_key), create(:user))

        assert_response(:not_found)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get { |user| edit_api_key_path(create(:api_key, user: user)) }
        end
      end
    end

    context("update action") do
      should("render for the API key owner") do
        put_auth(api_key_path(@api_key), @user, params: { api_key: { name: "blah" } })

        assert_redirected_to(user_api_keys_path(@user.id))
        assert_equal("blah", @api_key.reload.name)
      end

      should("fail for someone else") do
        put_auth(api_key_path(@api_key), create(:user))

        assert_response(:not_found)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).put { |user| api_key_path(create(:api_key, user: user)) }.params({ api_key: { name: "blah" } }).success(:redirect)
          access.gte(User::Levels::REJECTED).json.put { |user| api_key_path(create(:api_key, user: user)) }.params({ api_key: { name: "blah" } })
        end
      end
    end

    context("destroy action") do
      should("delete the user's API key") do
        delete_auth(api_key_path(@api_key), @user)

        assert_redirected_to(user_api_keys_path(@user.id))
        assert_raise(ActiveRecord::RecordNotFound) { @api_key.reload }
      end

      should("not allow deleting another user's API key") do
        delete_auth(api_key_path(@api_key), create(:user))

        assert_response(:not_found)
        assert_not_nil(@api_key.reload)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).delete { |user| api_key_path(create(:api_key, user: user)) }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.delete { |user| api_key_path(create(:api_key, user: user)) }
        end
      end
    end
  end
end

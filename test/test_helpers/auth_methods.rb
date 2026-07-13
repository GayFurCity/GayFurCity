# frozen_string_literal: true

module TestHelpers
  module AuthMethods
    extend(ActiveSupport::Concern)

    def login_as(user)
      post(session_path, params: { session: { name: user.name, password: user.password } })

      if user.mfa.present?
        post(verify_mfa_session_path, params: { mfa: { user_id: user.signed_id(purpose: :verify_mfa), code: user.mfa.code } })
      end
    end

    def method_authenticated(method_name, url, user, options)
      login_as(user)
      send(method_name, url, **options)
    end

    def get_auth(url, user, options = {})
      method_authenticated(:get, url, user, options)
    end

    def post_auth(url, user, options = {})
      method_authenticated(:post, url, user, options)
    end

    def put_auth(url, user, options = {})
      method_authenticated(:put, url, user, options)
    end

    def patch_auth(url, user, options = {})
      method_authenticated(:patch, url, user, options)
    end

    def delete_auth(url, user, options = {})
      method_authenticated(:delete, url, user, options)
    end
  end
end

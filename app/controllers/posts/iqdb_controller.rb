# frozen_string_literal: true

module Posts
  class IqdbController < ApplicationController
    respond_to(:html, :json)
    # Show uses POST because it needs a file parameter. This would be GET otherwise.
    skip_forgery_protection(only: :show)
    before_action(:validate_enabled)
    skip_before_action(:api_check, if: -> { CurrentUser.user.is_owner? })

    def show
      authorize(:iqdb)
      # Allow legacy ?post_id=123 parameters
      search_params = params[:search].presence || params
      throttle(search_params)

      @matches = []
      if search_params[:file].present?
        if search_params[:file].is_a?(ActionDispatch::Http::UploadedFile)
          @matches = IqdbProxy.query_file(search_params[:file].tempfile, search_params[:score_cutoff])
        else
          return render_expected_error(400, "Invalid file")
        end
      elsif search_params[:url].present?
        parsed_url = begin
          Addressable::URI.heuristic_parse(search_params[:url])
        rescue StandardError
          nil
        end
        raise(User::PrivilegeError, "Invalid URL") unless parsed_url
        whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url, CurrentUser.user)
        raise(User::PrivilegeError, "Not allowed to request content from this URL") unless whitelist_result[0]
        @matches = IqdbProxy.query_url(CurrentUser.user, search_params[:url], search_params[:score_cutoff])
      elsif search_params[:post_id].present?
        @matches = IqdbProxy.query_post(Post.find_by(id: search_params[:post_id]), search_params[:score_cutoff])
      elsif search_params[:hash].present?
        @matches = IqdbProxy.query_hash(search_params[:hash], search_params[:score_cutoff])
      end

      respond_with(@matches) do |fmt|
        fmt.json do
          render(json: @matches)
        end
      end
    rescue IqdbProxy::Error => e
      render_expected_error(500, e.message)
    end

    private

    def throttle(search_params)
      return if GayFurCity.config.disable_throttles? || CurrentUser.user.is_trusted?

      if %i[file url post_id hash].any? { |key| search_params[key].present? }
        if RateLimiter.check_limit("img:#{CurrentUser.ip_addr}", 1, 2.seconds)
          raise(APIThrottled)
        else
          RateLimiter.hit("img:#{CurrentUser.ip_addr}", 2.seconds)
        end
      end
    end

    def validate_enabled
      raise(FeatureUnavailable) unless IqdbProxy.enabled?
    end
  end
end

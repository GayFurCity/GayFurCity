# frozen_string_literal: true

module Posts
  class ErisController < ApplicationController
    respond_to(:html, :json)
    # Show uses POST because it needs a file parameter. This would be GET otherwise.
    skip_forgery_protection(only: :show)
    before_action(:validate_enabled)
    skip_before_action(:api_check, if: -> { CurrentUser.user.is_owner? })

    def show
      authorize(:eris)
      # Allow legacy ?post_id=123 parameters
      search_params = params[:search].presence || params
      throttle(search_params)

      @matches = []
      if search_params[:file].present?
        return render_eris_error(400, "The uploaded file could not be processed. Please try a different file.") unless search_params[:file].is_a?(ActionDispatch::Http::UploadedFile)
        @matches = ErisProxy.query_file(search_params[:file].tempfile, search_params[:score_cutoff])
      elsif search_params[:url].present?
        parsed_url = begin
          Addressable::URI.heuristic_parse(search_params[:url].to_s, scheme: "https")
        rescue StandardError
          nil
        end
        return render_eris_error(400, "The URL must begin with http:// or https://.") unless parsed_url&.scheme.in?(%w[http https]) && parsed_url.host.present?
        whitelist_result = UploadWhitelist.is_whitelisted?(parsed_url, CurrentUser.user)
        return render_eris_error(403, "Not allowed to request content from this URL") unless whitelist_result[0]
        @matches = ErisProxy.query_url(CurrentUser.user, parsed_url.to_s, search_params[:score_cutoff])
      elsif search_params[:post_id].present?
        return render_eris_error(400, "Please enter a valid post ID.") unless search_params[:post_id].to_s =~ /\A\d+\z/
        @matches = ErisProxy.query_post(search_params[:post_id], search_params[:score_cutoff])
      elsif search_params[:hash].present?
        return render_eris_error(400, "Please enter a valid hash.") unless search_params[:hash].is_a?(String) && search_params[:hash] =~ /\A[0-9a-fA-F]+\z/
        @matches = ErisProxy.query_hash(search_params[:hash], search_params[:score_cutoff])
      end

      respond_with(@matches) do |fmt|
        fmt.json do
          render(json: @matches)
        end
      end
    rescue Downloads::File::Error, ActiveModel::ValidationError => e
      render_eris_error(422, e.message)
    rescue ErisProxy::BusyError => e
      render_eris_error(429, e.message)
    rescue ErisProxy::Error => e
      render_eris_error(503, e.message)
    end

    private

    # Shows expected errors on the search form instead of the error page
    def render_eris_error(status, message)
      if request.format.html?
        @error = message
        @matches ||= []
        render(:show, status: status)
      else
        render_expected_error(status, message)
      end
    end

    def throttle(search_params)
      return if GayFurCity.config.disable_throttles? || CurrentUser.user.is_trusted?

      # file and url searches need the image downloaded and processed, post_id and hash searches don't
      if %i[file url].any? { |key| search_params[key].present? }
        enforce_throttle!("heavy", anon_limit: 1, anon_period: 60.seconds, user_limit: 6, user_period: 10.seconds)
      elsif %i[post_id hash].any? { |key| search_params[key].present? }
        enforce_throttle!("light", anon_limit: 10, anon_period: 10.seconds, user_limit: 10, user_period: 10.seconds)
      end
    end

    def enforce_throttle!(type, anon_limit:, anon_period:, user_limit:, user_period:)
      if CurrentUser.user.is_anonymous?
        raise(APIThrottled) if ErisProxy.anon_lockdown?
        keys = ["eris:#{type}:anon:#{CurrentUser.ip_addr}"]
        limit = anon_limit
        period = anon_period
      else
        keys = ["eris:#{type}:#{CurrentUser.ip_addr}", "eris:#{type}:user:#{CurrentUser.user.id}"]
        limit = user_limit
        period = user_period
      end

      raise(APIThrottled) if keys.any? { |key| RateLimiter.check_limit(key, limit, period) }
      keys.each { |key| RateLimiter.hit(key, period) }
    end

    def validate_enabled
      raise(FeatureUnavailable) unless ErisProxy.enabled?
    end
  end
end

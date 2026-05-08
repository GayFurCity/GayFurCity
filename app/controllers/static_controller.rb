# frozen_string_literal: true

class StaticController < ApplicationController
  respond_to(:text, only: %i[robots])
  respond_to(:xml, only: %i[site_map])
  before_action(:ensure_lockdown_disabled, only: %i[discord])
  respond_to(:html)

  def privacy
    @page = view_context.safe_wiki("help:privacy_policy")
  end

  def terms_of_service
    @page = view_context.safe_wiki("help:terms_of_service")
  end

  def contact
    @page = view_context.safe_wiki("help:contact")
  end

  def takedown
    @page = view_context.safe_wiki("help:takedown")
  end

  def staff
    @page = view_context.safe_wiki("help:staff")
  end

  def avoid_posting
    @page = view_context.safe_wiki(Config.instance.avoid_posting_notice_wiki_page)
  end

  def not_found
    render("static/404", formats: %i[html], status: :not_found)
  end

  def error
  end

  def site_map
    if request.format.xml?
      expires_in(1.day, public: true)
      case params[:type]
      when nil, ""
        render(partial: "static/site_maps/index")
      when "main"
        render(partial: "static/site_maps/main")
      when "posts"
        render(partial: "static/site_maps/posts", locals: { from: params[:from].to_i, to: params[:to].to_i })
      end
    end
  end

  def home
    render(layout: "blank")
  end

  def theme
  end

  def toggle_mobile_mode
    if CurrentUser.user.is_member?
      user = CurrentUser.user
      user.disable_responsive_mode = !user.disable_responsive_mode
      user.save
    elsif cookies[:nmm]
      cookies.delete(:nmm)
    else
      cookies.permanent[:nmm] = "1"
    end
    redirect_back_or_to(posts_path)
  end

  def discord
    unless CurrentUser.can_discord?
      raise(User::PrivilegeError, "You must have an account for at least one week in order to join the Discord server.")
    end
    if request.post?
      time = (Time.now + 5.minutes).to_i
      secret = GayFurCity.config.discord_secret
      hashed_values = Digest::SHA256.hexdigest("#{CurrentUser.user.id};#{CurrentUser.user.name};#{time};#{secret};index")
      user_hash = "?user_id=#{CurrentUser.user.id}&user_name=#{CurrentUser.user.name}&time=#{time}&hash=#{hashed_values}"

      redirect_to(GayFurCity.config.discord_site + user_hash, allow_other_host: true)
    else
      @page = view_context.safe_wiki(Config.instance.discord_notice_wiki_page)
    end
  end

  def robots
    expires_in(1.day, public: true)
  end

  def recognize_route
    method = params[:method]&.upcase || "GET"
    route = Rails.application.routes.recognize_path(params[:url], method: method)
    route[:api] = "#{route[:controller]}:#{route[:action]}"
    render(json: route)
  rescue ActionController::RoutingError
    render_expected_error(400, "Invalid url: #{method} #{params[:url]}", format: :json)
  end

  private

  def format_wiki_page(name)
    wiki = WikiPage.titled(name)
    return WikiPage.new(body: "Wiki page \"#{name}\" not found.") if wiki.blank?
    wiki
  end

  def ensure_lockdown_disabled
    access_denied("Discord is disabled") if Security::Lockdown.discord_disabled? && !CurrentUser.user.is_staff?
  end
end

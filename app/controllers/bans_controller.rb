# frozen_string_literal: true

class BansController < ApplicationController
  respond_to(:html)
  respond_to(:json, only: %i[index show])

  def index
    @bans = authorize(Ban).html_includes(request, :user, :creator)
                          .search_current(search_params(Ban))
                          .paginate(params[:page], limit: params[:limit])
    respond_with(@bans)
  end

  def show
    @ban = authorize(Ban.find(params[:id]))
    respond_with(@ban)
  end

  def new
    @ban = authorize(Ban.new_with_current(:creator, permitted_attributes(Ban)))
  end

  def edit
    @ban = authorize(Ban.find(params[:id]))
  end

  def create
    @ban = authorize(Ban.new_with_current(:creator, permitted_attributes(Ban)))
    @ban.save

    notice("Ban created") if @ban.valid?
    respond_with(@ban)
  end

  def update
    @ban = authorize(Ban.find(params[:id]))
    @ban.update_with_current(:updater, permitted_attributes(@ban))

    notice("Ban updated") if @ban.valid?
    respond_with(@ban)
  end

  def destroy
    @ban = authorize(Ban.find(params[:id]))
    @ban.destroy_with_current(:destroyer)

    notice("Ban destroyed")
    respond_with(@ban)
  end

  def acknowledge
    @user = User.find_signed!(params[:user_id], purpose: :acknowledge_ban)
    return render_expected_error(403, "You are not banned") unless @user.is_banned?
    @ban = @user.recent_ban
    if params[:commit] == "Acknowledge"
      return render_expected_error(403, "Your ban has not expired") unless @ban.try(:expired?)
      @user.unban!(CurrentUser.user, ack: true)
      redirect_to(new_session_path, notice: "Your ban has been removed, please log in again")
    else
      @notice = view_context.safe_wiki(Config.instance.ban_notice_wiki_page).body
                            .gsub("%BAN_REASON%", @ban.reason)
                            .gsub("%BAN_USER%", view_context.link_to_user(@ban.creator))
    end
  end
end

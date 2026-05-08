# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action(:requires_reauthentication)
  before_action(:load_api_key, except: %i[index new create])
  respond_to(:html, :json)

  def index
    params[:search][:user_id] ||= params[:user_id]
    @api_keys = authorize(ApiKey).includes_if(params[:user_id].blank?, :user)
                                 .search_current(search_params(ApiKey))
                                 .paginate(params[:page], limit: params[:limit])
    respond_with(@api_keys)
  end

  def new
    @api_key = authorize(ApiKey.new_with_current(:user))
    respond_with(@api_key)
  end

  def edit
    authorize(@api_key)
    respond_with(@api_key)
  end

  def create
    @api_key = authorize(ApiKey.new_with_current(:user, permitted_attributes(ApiKey)))
    @api_key.save
    notice(@api_key.valid? ? "API key created" : @api_key.errors.full_messages.join("; "))
    respond_with(@api_key, location: user_api_keys_path(CurrentUser.user))
  end

  def update
    authorize(@api_key)
    @api_key.update_with_current(:updater, permitted_attributes(@api_key))
    notice("API key updated")
    respond_with(@api_key, location: user_api_keys_path(CurrentUser.user))
  end

  def destroy
    authorize(@api_key)
    @api_key.destroy_with_current(:destroyer)
    notice("API key deleted")
    respond_with(@api_key, location: user_api_keys_path(CurrentUser.user))
  end

  def usage
    authorize(@api_key)
    date = params[:date].present? ? Date.parse(params[:date].to_s) : nil
    limit = (params[:limit] || 100).to_i
    page = (params[:page] || 1).to_i
    usage = Reports.get_api_key_usages(@api_key.id, date: date, limit: limit, page: page)
    @usages = GayFurCity::Paginator::PaginatedArray.new(usage.data.to_a, { pagination_mode: :numbered, records_per_page: limit, total_count: usage.count, current_page: page })
    respond_with(@usages)
  end

  private

  def load_api_key
    @api_key = ApiKey.visible(CurrentUser.user).find(params[:id])
  end
end

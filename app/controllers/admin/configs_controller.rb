# frozen_string_literal: true

module Admin
  class ConfigsController < ApplicationController
    respond_to(:html, :json)
    def show
      @config = authorize(Config.uncached)
      respond_with(@config)
    end

    def update
      @config = authorize(Config.uncached)
      input = params[:config].permit!
      attr = policy(@config).permitted_attributes_for_update
      input.select! { |key,| attr.include?(key.to_sym) }
      values = input.to_h do |key, value|
        col = Config.columns.find { |c| c.name == key }
        if value.is_a?(Hash)
          next [key, value.reject { |_k, v| v == "" }.transform_values(&:to_i)]
        end
        next [key, value] if col&.null == true && value == ""
        next [key, value.to_i] if col&.type == :integer
        next [key, value.to_s.truthy?] if col&.type == :boolean
        [key, value]
      end
      @config.update_with!(CurrentUser.user, values)
      notice("Config updated")
      respond_with(@config) do |format|
        format.html { redirect_back_or_to(admin_config_path) }
      end
    end
  end
end

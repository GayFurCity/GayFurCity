# frozen_string_literal: true

class DbExportsController < ApplicationController
  respond_to(:html, :json)
  before_action(:validate_enabled)

  def index
    @exports = DbExport.order(:name, :date)
    respond_with(@exports)
  end

  private

  def validate_enabled
    raise(FeatureUnavailable) unless Config.db_exports_enabled?
  end
end

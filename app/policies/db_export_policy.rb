# frozen_string_literal: true

class DbExportPolicy < ApplicationPolicy
  def api_attributes
    super + %i[file_name url]
  end
end

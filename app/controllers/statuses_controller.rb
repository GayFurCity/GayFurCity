# frozen_string_literal: true

class StatusesController < ApplicationController
  def show
    @results = ServiceStatusChecker.check_all
  end
end

# frozen_string_literal: true

class SystemsController < ApplicationController
  def show
    @info = authorize(SystemInfo.new).load_all
  end

  def dbsize
    @info = authorize(SystemInfo.new).dbsize.load
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))
require("faker")

ENV["RAILS_ENV"] ||= "development"
ENV["GAYFURCITY_DISABLE_THROTTLES"] = "1"

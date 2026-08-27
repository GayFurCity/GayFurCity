#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

config = AdminConfig.uncached

updates = {}
updates[:app_name] = "GayFur City" if config.app_name == "Femboy Fans"
updates[:canonical_app_name] = "GayFur City" if config.app_name == "Femboy Fans"
updates[:app_description] = "Your one-stop shop for gay furries." if config.app_description == "Your one-stop shop for femboy furries."
updates[:takedown_email] = "admin@gayfur.city" if config.takedown_email == "admin@femboy.fan"
updates[:contact_email] = "admin@gayfur.city" if config.takedown_email == "admin@femboy.fan"

if updates.none?
  puts("no config changes")
else
  config.update_with!(User.system, updates)
  puts("config changes: #{updates.keys.join(', ')}")
end

mascots = Mascot.where.contains(available_on: ["Femboy Fans"])

if mascots.none?
  puts("no mascot changes")
else
  mascots.each { |m| m.update_with!(User.system, available_on: ["GayFur City", *(m.available_on - ["Femboy Fans"])]) }
  puts("mascot changes: #{mascots.map(&:id).join(', ')}")
end

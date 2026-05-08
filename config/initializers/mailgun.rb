# frozen_string_literal: true

Mailgun.configure do |config|
  config.api_key = GayFurCity.config.email_mailgun_api_key
end

# frozen_string_literal: true

class EmailLinkValidator
  def self.generate(message, purpose, expires = nil)
    validator.generate(message, purpose: purpose, expires_in: expires)
  end

  def self.validate(hash, purpose)
    message = validator.verify(hash, purpose: purpose)
    return false if message.nil?
    message
  rescue StandardError
    false
  end

  def self.validator
    @validator ||= ActiveSupport::MessageVerifier.new(GayFurCity.config.email_key, serializer: JSON, digest: "SHA256")
  end

  private_class_method(:validator)
end

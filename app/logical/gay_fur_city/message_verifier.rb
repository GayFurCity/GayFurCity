# frozen_string_literal: true

module GayFurCity
  class MessageVerifier
    attr_reader(:purpose, :secret, :verifier)

    def initialize(purpose)
      @purpose = purpose
      @secret = Rails.application.key_generator.generate_key(purpose.to_s)
      @verifier = ActiveSupport::MessageVerifier.new(secret, serializer: ::JSON, digest: "SHA256")
    end

    def generate(*, **)
      verifier.generate(*, purpose: purpose, **)
    end

    def verify(*, **)
      verifier.verify(*, purpose: purpose, **)
    end

    def verified(*, **)
      verifier.verified(*, purpose: purpose, **)
    end
  end
end

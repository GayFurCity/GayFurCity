module TestHelpers
  module AssertMethods
    extend(ActiveSupport::Concern)

    def assert_error_response(key, *messages)
      assert_not_nil(@response.parsed_body.dig("errors", key))
      assert_same_elements(messages, @response.parsed_body.dig("errors", key))
    end
  end
end

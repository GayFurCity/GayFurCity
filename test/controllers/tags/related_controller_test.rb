# frozen_string_literal: true

require("test_helper")

module Tags
  class RelatedControllerTest < ActionDispatch::IntegrationTest
    context("The related tags controller") do
      context("show action") do
        should("work") do
          get_auth(related_tags_path, create(:user), params: { query: "touhou" })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED) { |user| get_auth(related_tags_path, user) }
        end
      end
    end
  end
end

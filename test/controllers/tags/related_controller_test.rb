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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).get(related_tags_path)
            access.gte(User::Levels::REJECTED).json.get(related_tags_path)
          end
        end
      end
    end
  end
end

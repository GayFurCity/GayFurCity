# frozen_string_literal: true

require("test_helper")

class DomainIconsControllerTest < ActionDispatch::IntegrationTest
  context("The domain icons controller") do
    setup do
      @admin = create(:admin_user)
      @domain_icon = create(:domain_icon, creator: @admin, domain: "e621.net", aliases: %w[e926.net])
    end

    context("index action") do
      should("render") do
        get_auth(domain_icons_path, @admin)

        assert_response(:success)
      end

      should("search by alias") do
        get_auth(domain_icons_path, @admin, params: { search: { domain_matches: "e926.net" }, format: :json })

        assert_equal([@domain_icon.id], response.parsed_body.pluck("id"))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(domain_icons_path)
        end
      end
    end

    context("new action") do
      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get(new_domain_icon_path)
        end
      end
    end

    context("edit action") do
      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_domain_icon_path(@domain_icon) }
        end
      end
    end

    context("create action") do
      should("create an icon") do
        assert_difference(-> { DomainIcon.count } => 1, -> { ModAction.where(action: "domain_icon_create").count } => 1) do
          post_auth(domain_icons_path, @admin, params: { domain_icon: { domain: "furaffinity.net", aliases_string: "facdn.net", file: fixture_file_upload("test-icon-32.png") } })
        end

        assert_redirected_to(domain_icons_path)
        assert_equal(%w[facdn.net], DomainIcon.find_by(domain: "furaffinity.net").aliases)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).post(domain_icons_path).params { { domain_icon: { domain: "#{SecureRandom.hex(4)}.example.net", file: fixture_file_upload("test-icon-32.png") } } }.success(:redirect)
        end
      end
    end

    context("update action") do
      should("update the aliases without a new file") do
        assert_difference(-> { ModAction.where(action: "domain_icon_update").count } => 1) do
          put_auth(domain_icon_path(@domain_icon), @admin, params: { domain_icon: { aliases_string: "e926.net e621.ws" } })
        end

        assert_redirected_to(domain_icons_path)
        assert_equal(%w[e926.net e621.ws], @domain_icon.reload.aliases)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).put { domain_icon_path(@domain_icon) }.params({ domain_icon: { aliases_string: "e926.net" } }).success(:redirect)
        end
      end
    end

    context("destroy action") do
      should("delete the icon") do
        assert_difference(-> { DomainIcon.count } => -1, -> { ModAction.where(action: "domain_icon_delete").count } => 1) do
          delete_auth(domain_icon_path(@domain_icon), @admin)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { domain_icon_path(@domain_icon) }.success(:redirect)
        end
      end
    end
  end
end

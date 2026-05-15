# frozen_string_literal: true

require("test_helper")

class IpBansControllerTest < ActionDispatch::IntegrationTest
  context("The ip bans controller") do
    setup do
      @admin = create(:admin_user)
    end

    context("new action") do
      should("render") do
        get_auth(new_ip_ban_path, @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get(new_ip_ban_path)
        end
      end
    end

    context("create action") do
      should("work") do
        assert_difference("IpBan.count", 1) do
          post_auth(ip_bans_path, @admin, params: { ip_ban: { ip_addr: "1.2.3.4", reason: "xyz" } })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).post(ip_bans_path).params { { ip_ban: { ip_addr: "100.#{rand(0..255)}.#{rand(0..255)}.#{rand(0..255)}", reason: "xyz" } } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.post(ip_bans_path).params { { ip_ban: { ip_addr: "100.#{rand(0..255)}.#{rand(0..255)}.#{rand(0..255)}", reason: "xyz" } } }
        end
      end
    end

    context("index action") do
      setup do
        create(:ip_ban, ip_addr: "1.2.3.4")
      end

      should("render") do
        get_auth(ip_bans_path, @admin)

        assert_response(:success)
      end

      should("render with search parameters") do
        get_auth(ip_bans_path, @admin, params: { search: { ip_addr: "1.2.3.4" } })

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get(ip_bans_path)
          access.gte(User::Levels::ADMIN).json.get(ip_bans_path)
        end
      end

      context("search parameters") do
        subject { ip_bans_path }
        setup do
          IpBan.delete_all
          @creator = create(:admin_user)
          @admin = create(:admin_user)
          @ip_ban = create(:ip_ban, creator: @creator, creator_ip_addr: "127.0.0.2", ip_addr: "1.2.3.4", reason: "foo")
        end

        asserts do
          search(:reason, "foo").records { [@ip_ban] }.user { @admin }
          search(:ip_addr, "1.2.3.4").records { [@ip_ban] }.user { @admin }
          search(:creator_id).value { @creator.id }.records { [@ip_ban] }.user { @admin }
          search(:creator_name).value { @creator.name }.records { [@ip_ban] }.user { @admin }
          search(:creator_ip_addr, "127.0.0.2").records { [@ip_ban] }.user { @admin }
          search.shared.records { [@ip_ban] }.user { @admin }
        end
      end
    end

    context("destroy action") do
      setup do
        @ip_ban = create(:ip_ban, ip_addr: "1.2.3.4")
      end

      should("work") do
        assert_difference("IpBan.count", -1) do
          delete_auth(ip_ban_path(@ip_ban), @admin, params: { format: "js" })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { ip_ban_path(@ip_ban) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { ip_ban_path(@ip_ban) }.success(:no_content)
        end
      end
    end
  end
end

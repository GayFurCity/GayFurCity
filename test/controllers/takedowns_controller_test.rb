# frozen_string_literal: true

require("test_helper")

class TakedownsControllerTest < ActionDispatch::IntegrationTest
  context("The takedowns controller") do
    context("index action") do
      should("render") do
        create_list(:takedown, 2)
        get(takedowns_path)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(takedowns_path, user) }
      end

      context("search parameters") do
        subject { takedowns_path }
        setup do
          Takedown.delete_all
          @creator = create(:user)
          @updater = create(:user)
          @approver = create(:user)
          @janitor = create(:janitor_user)
          @admin = create(:admin_user)
          @owner = create(:owner_user)
          @post = create(:post, uploader: @creator)
          @takedown = create(:takedown,
                             creator: @creator, creator_ip_addr: "127.0.0.2",
                             updater: @updater, updater_ip_addr: "127.0.0.3",
                             approver: @approver, source: "https://google.com",
                             reason: "foo", instructions: "bar",
                             notes: "baz", reason_hidden: false,
                             email: "qux@example.com", vericode: "abc123",
                             status: "approved", post_ids: @post.id.to_s)
        end

        assert_search_param(:source, "https://google.com", -> { [@takedown] }, -> { @janitor })
        assert_search_param(:reason, "foo", -> { [@takedown] }, -> { @janitor })
        assert_search_param(:instructions, "bar", -> { [@takedown] }, -> { @janitor })
        assert_search_param(:notes, "baz", -> { [@takedown] }, -> { @janitor })
        assert_search_param(:reason_hidden, "false", -> { [@takedown] }, -> { @janitor })
        assert_search_param(:email, "qux@example.com", -> { [@takedown] }, -> { @owner })
        assert_search_param(:vericode, "abc123", -> { [@takedown] }, -> { @owner })
        assert_search_param(:status, "approved", -> { [@takedown] })
        assert_search_param(:post_id, -> { @post.id }, -> { [@takedown] }, -> { @janitor })
        assert_search_param(:creator_id, -> { @creator.id }, -> { [@takedown] }, -> { @janitor })
        assert_search_param(:creator_name, -> { @creator.name }, -> { [@takedown] }, -> { @janitor })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@takedown] }, -> { @admin })
        assert_search_param(:updater_id, -> { @updater.id }, -> { [@takedown] }, -> { @janitor })
        assert_search_param(:updater_name, -> { @updater.name }, -> { [@takedown] }, -> { @janitor })
        assert_search_param(:updater_ip_addr, "127.0.0.3", -> { [@takedown] }, -> { @admin })
        assert_search_param(:approver_id, -> { @approver.id }, -> { [@takedown] })
        assert_search_param(:approver_name, -> { @approver.name }, -> { [@takedown] })
        assert_shared_search_params(-> { [@takedown] })
      end
    end

    should("allow creation") do
      takedown_post = create(:post)
      post(takedowns_path, params: { takedown: { email: "dummy@example.com", reason: "foo", post_ids: "#{takedown_post.id} #{takedown_post.id + 1}" }, format: :json })

      assert_response(:redirect)

      takedown = Takedown.last

      assert_redirected_to(takedown_path(takedown, code: takedown.vericode))
      assert_equal(takedown_post.id.to_s, takedown.post_ids)
      assert_operator(takedown.vericode.length, :>, 8)
    end
  end
end

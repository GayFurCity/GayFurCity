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

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(takedowns_path)
          access.gte(User::Levels::ANONYMOUS).json.get(takedowns_path)
        end
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

        asserts do
          search(:source, "https://google.com").records { [@takedown] }.user { @janitor }
          search(:reason, "foo").records { [@takedown] }.user { @janitor }
          search(:instructions, "bar").records { [@takedown] }.user { @janitor }
          search(:notes, "baz").records { [@takedown] }.user { @janitor }
          search(:reason_hidden, "false").records { [@takedown] }.user { @janitor }
          search(:email, "qux@example.com").records { [@takedown] }.user { @owner }
          search(:vericode, "abc123").records { [@takedown] }.user { @owner }
          search(:status, "approved").records { [@takedown] }
          search(:post_id).value { @post.id }.records { [@takedown] }.user { @janitor }
          search(:creator_id).value { @creator.id }.records { [@takedown] }.user { @janitor }
          search(:creator_name).value { @creator.name }.records { [@takedown] }.user { @janitor }
          search(:ip_addr, "127.0.0.2").records { [@takedown] }.user { @admin }
          search(:updater_id).value { @updater.id }.records { [@takedown] }.user { @janitor }
          search(:updater_name).value { @updater.name }.records { [@takedown] }.user { @janitor }
          search(:updater_ip_addr, "127.0.0.3").records { [@takedown] }.user { @admin }
          search(:approver_id).value { @approver.id }.records { [@takedown] }
          search(:approver_name).value { @approver.name }.records { [@takedown] }
          search.shared.records { [@takedown] }
        end
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

    should("allow updating reviewer fields") do
      owner = create(:owner_user)
      post1 = create(:post)
      post2 = create(:post)
      takedown = create(:takedown, post_ids: "#{post1.id} #{post2.id}", del_post_ids: post1.id.to_s)

      put_auth(takedown_path(takedown), owner, params: {
        takedown:       { notes: "reviewed", reason_hidden: "1", status: "inactive" },
        takedown_posts: { post1.id.to_s => "0", post2.id.to_s => "1" },
      })

      assert_redirected_to(takedown_path(takedown))
      takedown.reload

      assert_equal("reviewed", takedown.notes)
      assert_predicate(takedown, :reason_hidden?)
      assert_equal("inactive", takedown.status)
      assert_equal(post2.id.to_s, takedown.del_post_ids)
      assert_equal(owner, takedown.updater)
    end
  end
end

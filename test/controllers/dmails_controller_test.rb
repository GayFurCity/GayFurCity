# frozen_string_literal: true

require("test_helper")

class DmailsControllerTest < ActionDispatch::IntegrationTest
  context("The dmails controller") do
    setup do
      @user = create(:user)
      @user2 = create(:user)
      @mod = create(:moderator_user)
      @dmail = create(:dmail, owner: @user, to: @user, from: @user2)
    end

    context("new action") do
      should("render") do
        get_auth(new_dmail_path, @user)

        assert_response(:success)
      end

      context("with a respond_to_id") do
        should("check privileges") do
          get_auth(new_dmail_path, @user2, params: { respond_to_id: @dmail.id })

          assert_response(:forbidden)
        end

        should("prefill the fields") do
          get_auth(new_dmail_path, @user, params: { respond_to_id: @dmail.id })

          assert_response(:success)
        end

        context("and a forward flag") do
          should("not populate the to field") do
            get_auth(new_dmail_path, @user, params: { respond_to_id: @dmail.id, forward: true })

            assert_response(:success)
          end
        end
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| get_auth(new_dmail_path, user) }
      end
    end

    context("index action") do
      should("show dmails owned by the current user by sent") do
        get_auth(dmails_path, @user, params: { folder: "sent" })

        assert_response(:success)
      end

      should("show dmails owned by the current user by received") do
        get_auth(dmails_path, @user, params: { older: "received" })

        assert_response(:success)
      end

      should("not show dmails not owned by the current user") do
        get_auth(dmails_path, @user, params: { search: { owner_id: @dmail.owner_id } })

        assert_response(:success)
      end

      should("work for json") do
        get_auth(dmails_path, @user, params: { format: :json })

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| get_auth(dmails_path, user) }
      end

      context("search parameters") do
        subject { dmails_path }
        setup do
          Dmail.delete_all
          @to = create(:user)
          @from = create(:user)
          @dmail = create(:dmail, to: @to, from: @from, from_ip_addr: "127.0.0.2", owner: @to, title: "foo", body: "bar", is_read: true, is_deleted: false, is_spam: false)
          @owner = create(:owner_user)
        end

        assert_search_param(:title_matches, "foo", -> { [@dmail] }, -> { @to })
        assert_search_param(:message_matches, "bar", -> { [@dmail] }, -> { @to })
        assert_search_param(:is_read, "true", -> { [@dmail] }, -> { @to })
        assert_search_param(:is_deleted, "false", -> { [@dmail] }, -> { @to })
        assert_search_param(:is_spam, "false", -> { [@dmail] }, -> { @owner })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@dmail] }, -> { @owner })
        assert_search_param(:read, "true", -> { [@dmail] }, -> { @to })
        assert_search_param(:to_id, -> { @to.id }, -> { [@dmail] }, -> { @to })
        assert_search_param(:to_name, -> { @to.name }, -> { [@dmail] }, -> { @to })
        assert_search_param(:from_id, -> { @from.id }, -> { [@dmail] }, -> { @to })
        assert_search_param(:from_name, -> { @from.name }, -> { [@dmail] }, -> { @to })
        assert_search_param(:owner_id, -> { @to.id }, -> { [@dmail] }, -> { @to })
        assert_search_param(:owner_name, -> { @to.name }, -> { [@dmail] }, -> { @to })
        assert_shared_search_params(-> { [@dmail] }, -> { @to })
      end
    end

    context("show action") do
      should("show dmails owned by the current user") do
        get_auth(dmail_path(@dmail), @dmail.owner)

        assert_response(:success)
        assert_predicate(@dmail.reload, :is_read?)
        assert_predicate(@dmail.owner.notifications.last, :is_read?)
      end

      should("not mark the dmail as read for json requests") do
        get_auth(dmail_path(@dmail), @dmail.owner, params: { format: :json })

        assert_response(:success)
        assert_not_predicate(@dmail.reload, :is_read?)
        assert_not_predicate(@dmail.owner.notifications.last, :is_read?)
      end

      should("not mark the dmail as read when shown to users that don't own it") do
        get_auth(dmail_path(@dmail, key: @dmail.key), @mod)

        assert_response(:success)
        assert_not_predicate(@dmail.reload, :is_read?)
        assert_not_predicate(@dmail.owner.notifications.last, :is_read?)
      end

      should("not show dmails not owned by the current user") do
        get_auth(dmail_path(@dmail), @user2)

        assert_response(:forbidden)
      end

      should("show dmails with a key for moderators") do
        get_auth(dmail_path(@dmail, key: @dmail.key), @mod)

        assert_response(:success)
      end

      should("not show dmails with a key for non-moderators") do
        get_auth(dmail_path(@dmail, key: @dmail.key), @user2)

        assert_response(:forbidden)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| get_auth(dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
      end
    end

    context("mark as read action") do
      should("mark the dmail as read") do
        put_auth(mark_as_read_dmail_path(@dmail), @dmail.owner, params: { format: :json })

        assert_response(:success)
        assert_predicate(@dmail.reload, :is_read?)
        assert_predicate(@dmail.owner.notifications.last, :is_read?)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| put_auth(mark_as_read_dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
      end
    end

    context("mark as unread action") do
      should("mark the dmail as unread") do
        @dmail.mark_as_read!(@dmail.owner)

        assert_equal(0, @dmail.owner.reload.unread_dmail_count)
        assert_not_predicate(@dmail.owner, :has_mail?)
        assert_equal(0, @dmail.owner.reload.unread_notification_count)
        assert_not_predicate(@dmail.owner, :has_unread_notifications?)

        put_auth(mark_as_unread_dmail_path(@dmail), @dmail.owner, params: { format: :json })

        assert_response(:success)
        assert_not_predicate(@dmail.reload, :is_read?)
        assert_not_predicate(@dmail.owner.notifications.last, :is_read?)

        assert_equal(1, @dmail.owner.reload.unread_dmail_count)
        assert_predicate(@dmail.owner, :has_mail?)
        assert_equal(1, @dmail.owner.reload.unread_notification_count)
        assert_predicate(@dmail.owner, :has_unread_notifications?)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| put_auth(mark_as_unread_dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
      end
    end

    context("create action") do
      setup do
        @user2 = create(:user)
      end

      should("create two messages, one for the sender and one for the recipient") do
        assert_difference("Dmail.count", 2) do
          dmail_attribs = { to_id: @user2.id, title: "abc", body: "abc" }
          post_auth(dmails_path, @user, params: { dmail: dmail_attribs })

          assert_redirected_to(dmail_path(Dmail.last))
        end
      end

      should("restrict access") do
        @admin = create(:admin_user)
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| post_auth(dmails_path, user, params: { dmail: { to_id: @admin.id, title: "abc", body: "abc" } }) }
      end
    end

    context("destroy action") do
      should("allow deletion if the dmail is owned by the current user") do
        delete_auth(dmail_path(@dmail), @user)

        assert_redirected_to(dmails_path)
        @dmail.reload

        assert(@dmail.is_deleted)
      end

      should("not allow deletion if the dmail is not owned by the current user") do
        delete_auth(dmail_path(@dmail), @user2)
        @dmail.reload

        assert_not(@dmail.is_deleted)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| delete_auth(dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
      end
    end

    context("spam") do
      setup do
        @mod_dmail = create(:dmail, owner: @mod, from: @user, to: @mod)
        SpamDetector.stubs(:enabled?).returns(true)
        stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/comment-check}).to_return(status: 200, body: "true")
        stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/submit-spam}).to_return(status: 200, body: nil)
        stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/submit-ham}).to_return(status: 200, body: nil)
      end

      should("mark spam dmails as spam") do
        SpamDetector.any_instance.stubs(:spam?).returns(true)
        assert_difference({ "User.system.tickets.count" => 1, "Dmail.count" => 2 }) do
          post_auth(dmails_path, @user, params: { dmail: { to_id: @user2.id, title: "abc", body: "abc" } })

          assert_redirected_to(dmail_path(@user.sent_dmails.last))
        end
        @ticket = User.system.tickets.last
        @dmail = @user2.received_dmails.last

        assert_equal(@dmail, @ticket.model)
        assert_equal("Spam.", @ticket.reason)
        assert_predicate(@dmail, :is_spam?)
        assert_predicate(@dmail, :is_deleted?)
      end

      should("not mark moderator dmails as spam") do
        # no need to stub anything, it should return false due to Trusted+ bypassing spam checks
        assert_difference({ "User.system.tickets.count" => 0, "Dmail.count" => 2 }) do
          post_auth(dmails_path, @mod, params: { dmail: { to_id: @user.id, title: "abc", body: "abc" } })

          assert_redirected_to(dmail_path(@mod.sent_dmails.last))
        end
        @dmail = @user.received_dmails.last

        assert_not(@dmail.is_spam?)
        assert_not(@dmail.is_deleted?)
      end

      should("auto ban spammers") do
        SpamDetector.any_instance.stubs(:spam?).returns(true)
        Ticket.delete_all

        stub_const(SpamDetector, :AUTOBAN_THRESHOLD, 1) do
          assert_difference({ "Ban.count" => 1, "User.system.tickets.count" => 1, "Dmail.count" => 2 }) do
            post_auth(dmails_path, @user, params: { dmail: { to_id: @user2.id, title: "abc", body: "abc" } })

            assert_redirected_to(dmail_path(@user.sent_dmails.last))
          end
        end
        @ticket = User.system.tickets.last
        @dmail = @user2.received_dmails.last

        assert_equal(@dmail, @ticket.model)
        assert_equal("Spam.", @ticket.reason)
        assert_equal("Automatically Banned", @ticket.response)
        assert_equal("approved", @ticket.status)
        assert_predicate(@dmail, :is_spam?)
        assert_predicate(@dmail, :is_deleted?)
        assert_predicate(@user.reload, :is_banned?)
      end

      context("mark spam action") do
        should("work and report false negative") do
          SpamDetector.any_instance.expects(:spam!).times(1)

          assert_not(@mod_dmail.reload.is_spam?)
          put_auth(mark_spam_dmail_path(@mod_dmail), @mod)

          assert_redirected_to(dmail_path(@mod_dmail))
          assert_predicate(@mod_dmail.reload, :is_spam?)
        end

        should("work but not report false negative if ticket exists") do
          SpamDetector.any_instance.expects(:spam!).never
          User.system.tickets.create!(model: @mod_dmail, reason: "Spam.", creator_ip_addr: "127.0.0.1")

          assert_not(@mod_dmail.reload.is_spam?)
          put_auth(mark_spam_dmail_path(@mod_dmail), @mod)

          assert_redirected_to(dmail_path(@mod_dmail))
          assert_predicate(@mod_dmail.reload, :is_spam?)
        end

        should("restrict access") do
          SpamDetector.any_instance.stubs(:spam!).returns(true)
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(mark_spam_dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
        end
      end

      context("mark not spam action") do
        should("work and not report false positive") do
          SpamDetector.any_instance.expects(:ham!).never
          @mod_dmail.update_column(:is_spam, true)

          assert_predicate(@mod_dmail.reload, :is_spam?)
          put_auth(mark_not_spam_dmail_path(@mod_dmail), @mod)

          assert_redirected_to(dmail_path(@mod_dmail))
          assert_not(@mod_dmail.reload.is_spam?)
        end

        should("work and report false positive if ticket exists") do
          SpamDetector.any_instance.expects(:ham!).times(1)
          User.system.tickets.create!(model: @mod_dmail, reason: "Spam.", creator_ip_addr: "127.0.0.1")
          @mod_dmail.update_column(:is_spam, true)

          assert_predicate(@mod_dmail.reload, :is_spam?)
          put_auth(mark_not_spam_dmail_path(@mod_dmail), @mod)

          assert_redirected_to(dmail_path(@mod_dmail))
          assert_not(@mod_dmail.reload.is_spam?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(mark_not_spam_dmail_path(create(:dmail, owner: user, to: user, from: create(:user))), user) }
        end
      end
    end
  end
end

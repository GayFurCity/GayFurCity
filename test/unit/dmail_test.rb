# frozen_string_literal: true

require("test_helper")

class DmailTest < ActiveSupport::TestCase
  context("A dmail") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
    end

    context("filter") do
      setup do
        @recipient = create(:user)
        @recipient.create_dmail_filter(words: "banned")
        @dmail = build(:dmail, title: "xxx", body: "banned word here", to: @recipient, from: @user)
      end

      should("detect banned words") do
        assert(@recipient.dmail_filter.filtered?(@dmail))
      end

      should("autoread if it has a banned word") do
        @dmail.save

        assert_predicate(@dmail, :is_read?)
      end

      should("not update the recipient's has_mail if filtered") do
        @dmail.save
        @recipient.reload

        assert_not(@recipient.has_mail?)
      end

      should("be ignored when sender is a moderator") do
        @dmail = create(:dmail, body: "banned word here", to: @recipient, from: @mod)

        assert_not(@recipient.dmail_filter.filtered?(@dmail))
        assert_not(@dmail.is_read?)
        assert_predicate(@recipient, :has_mail?)
      end

      context("that is empty") do
        setup do
          @recipient.dmail_filter.update(words: "   ")
        end

        should("not filter everything") do
          assert_not(@recipient.dmail_filter.filtered?(@dmail))
        end
      end
    end

    context("search") do
      should("return results based on title contents") do
        dmail = create(:dmail, title: "xxx", body: "bbb", from: @user)

        matches = Dmail.search({ title_matches: "x*" }, @user)

        assert_equal([dmail.id], matches.map(&:id))

        matches = Dmail.search({ title_matches: "X*" }, @user)

        assert_equal([dmail.id], matches.map(&:id))

        matches = Dmail.search({ message_matches: "aaa" }, @user)

        assert_empty(matches)
      end

      should("return results based on body contents") do
        create(:dmail, body: "xxx", from: @user)
        matches = Dmail.search({ message_matches: "xxx" }, @user)

        assert_predicate(matches, :any?)
        matches = Dmail.search({ message_matches: "aaa" }, @user)

        assert_empty(matches)
      end
    end

    should("create only one row per send") do
      @new_user = create(:user)
      assert_difference("Dmail.count", 1) do
        Dmail.create!(to_id: @new_user.id, title: "foo", body: "foo", from: @user)
      end
    end

    should("should parse user names") do
      dmail = build(:dmail, from: @user)
      dmail.to_id = nil
      dmail.to_name = @user.name

      assert_equal(dmail.to_id, @user.id)
    end

    should("construct a response") do
      dmail = create(:dmail, from: @user)
      response = dmail.build_response

      assert_equal("Re: #{dmail.title}", response.title)
      assert_equal(dmail.from_id, response.to_id)
      assert_equal(dmail.to_id, response.from_id)
    end

    should("record the from user's ip addr") do
      dmail = create(:dmail, from: @user)

      assert_equal(@user.ip_addr, dmail.from_ip_addr.to_s)
    end

    should("send an email if the user wants it") do
      user = create(:user, receive_email_notifications: true)
      assert_difference("ActionMailer::Base.deliveries.size", 1) do
        create(:dmail, to: user)
      end
    end

    should("not send an email if no_email_notification is set") do
      user = create(:user, receive_email_notifications: true)
      assert_no_difference("ActionMailer::Base.deliveries.size") do
        create(:dmail, to: user, no_email_notification: true)
        Dmail.create_automated(to: user, title: "test", body: "abc", no_email_notification: true)
      end
      assert_equal(2, Dmail.count)
    end

    should("be marked as read after the user reads it") do
      dmail = create(:dmail, to: @user)

      assert_not(dmail.is_read?)
      dmail.mark_as_read!(@user)

      assert_predicate(dmail, :is_read?)
    end

    should("notify the recipient he has mail") do
      recipient = create(:user)
      dmail = Dmail.create!(title: "hello", body: "hello", to: recipient, from: @user)
      recipient.reload

      assert_predicate(recipient, :has_mail?)
      assert_equal(1, recipient.unread_dmail_count)

      dmail.mark_as_read!(recipient)

      recipient.reload

      assert_not(recipient.has_mail?)
      assert_equal(0, recipient.unread_dmail_count)
    end

    should("be visible to both the sender and the recipient") do
      recipient = create(:user)
      dmail = create(:dmail, from: @user, to: recipient)

      assert(dmail.visible_to?(@user))
      assert(dmail.visible_to?(recipient))
      assert_not(dmail.visible_to?(create(:user)))
    end

    should("allow either party to delete their own side without affecting the other") do
      recipient = create(:user)
      dmail = create(:dmail, from: @user, to: recipient)

      dmail.soft_delete_for!(recipient)

      assert_predicate(dmail.reload, :is_deleted_by_recipient?)
      assert_not(dmail.is_deleted_by_sender?)
      assert_not(Dmail.not_deleted_for(recipient).exists?(dmail.id))
      assert(Dmail.not_deleted_for(@user).exists?(dmail.id))

      dmail.soft_delete_for!(@user)

      assert_predicate(dmail.reload, :is_deleted_by_sender?)
    end

    context("that is automated") do
      setup do
        @bot = create(:user)
        User.stubs(:system).returns(@bot)
      end

      should("only create a copy for the recipient") do
        Dmail.create_automated(to: @user, title: "test", body: "test")

        assert(@user.received_dmails.exists?(from: @bot, title: "test", body: "test"))
      end

      should("fail gracefully if recipient doesn't exist") do
        assert_nothing_raised do
          dmail = Dmail.create_automated(to_name: "this_name_does_not_exist", title: "test", body: "test")

          assert_equal(["must exist"], dmail.errors[:to])
        end
      end
    end

    context("marking as read") do
      setup do
        @recipient = create(:user)
      end

      should("update the recipient's unread dmail count") do
        dmail = create(:dmail, to: @recipient, from: @user)

        assert_equal(1, @recipient.reload.unread_dmail_count)
        dmail.mark_as_read!(@recipient)

        assert_equal(0, @recipient.reload.unread_dmail_count)
      end

      should("mark all related notifications as read") do
        dmail = create(:dmail, to: @recipient, from: @user)

        assert_equal(1, @recipient.notifications.unread.count)
        dmail.mark_as_read!(@recipient)

        assert_equal(0, @recipient.notifications.unread.count)
      end
    end

    context("marking as unread") do
      setup do
        @recipient = create(:user)
      end

      should("update the recipient's unread dmail count") do
        dmail = create(:dmail, to: @recipient, from: @user)
        dmail.mark_as_read!(@recipient)

        assert_equal(0, @recipient.reload.unread_dmail_count)
        dmail.mark_as_unread!(@recipient)

        assert_equal(1, @recipient.reload.unread_dmail_count)
      end

      should("mark all related notifications as unread") do
        dmail = create(:dmail, to: @recipient, from: @user)
        dmail.mark_as_read!(@recipient)

        assert_equal(0, @recipient.notifications.unread.count)
        dmail.mark_as_unread!(@recipient)

        assert_equal(1, @recipient.notifications.unread.count)
      end
    end

    context("during validation") do
      subject { build(:dmail) }

      should_not(allow_value(" ").for(:title))
      should_not(allow_value(" ").for(:body))
      should_not(allow_value(nil).for(:to))
    end
  end
end

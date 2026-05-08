# frozen_string_literal: true

require("test_helper")

class DmailFilterTest < ActiveSupport::TestCase
  def create_dmail(body, title)
    Dmail.create_split!(to: @receiver, from: @sender, body: body, title: title)
  end

  context("A dmail filter") do
    setup do
      @receiver = create(:user)
      @sender = create(:user)
    end

    context("for a word") do
      setup do
        @dmail_filter = @receiver.create_dmail_filter(words: "banned")
      end

      should("filter on that word in the body") do
        create_dmail("banned", "okay")

        assert_predicate(@receiver.dmails.last, :is_read?)
      end

      should("filter on that word in the title") do
        create_dmail("okay", "banned")

        assert_predicate(@receiver.dmails.last, :is_read?)
      end

      should("be case insensitive") do
        create_dmail("Banned.", "okay")

        assert_predicate(@receiver.dmails.last, :is_read?)
      end
    end

    context("for a user name") do
      setup do
        @dmail_filter = @receiver.create_dmail_filter(words: @sender.name)
      end

      should("filter on the sender") do
        create_dmail("okay", "okay")

        assert_predicate(@receiver.dmails.last, :is_read?)
      end
    end

    context("containing multiple words") do
      should("filter dmails containing any of the words") do
        @receiver.create_dmail_filter(words: "foo bar spam")
        create_dmail("this is a test (not *SPAM*)", "hello world")

        assert_predicate(@receiver.dmails.last, :is_read?)
      end
    end
  end
end

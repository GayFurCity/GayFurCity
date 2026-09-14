# frozen_string_literal: true

require("test_helper")

class TicketsControllerTest < ActionDispatch::IntegrationTest
  def assert_ticket_create_permissions(users, model:, **params)
    users.each do |user, allow_create|
      if allow_create
        assert_difference("Ticket.count") do
          post_auth(tickets_path, user, params: { ticket: { **params, model_id: model.id, model_type: model.class.name, reason: "test" } })

          assert_response(:redirect)
        end
      else
        assert_no_difference("Ticket.count") do
          post_auth(tickets_path, user, params: { ticket: { **params, model_id: @content.id, model_type: model.class.name, reason: "test" } })

          assert_response(:forbidden)
        end
      end
    end
  end

  context("The tickets controller") do
    setup do
      @admin = create(:admin_user)
      @janitor = create(:janitor_user)
      @user = create(:user)
      @reporter = create(:user)
      @bad_actor = create(:user, created_at: 2.weeks.ago)
    end

    context("index action") do
      context("search parameters") do
        subject { tickets_path }
        setup do
          Ticket.delete_all
          @creator = create(:user)
          @handler = create(:user)
          @claimant = create(:user)
          @accused = create(:user)
          @mod = create(:moderator_user)
          @admin = create(:admin_user)
          @forum_post = create(:forum_post, creator: @accused)
          @ticket = create(:ticket, creator: @creator, creator_ip_addr: "127.0.0.2", handler: @handler, handler_ip_addr: "127.0.0.3", claimant: @claimant, reason: "foo", status: "approved", model: @forum_post)
        end

        asserts do
          search(:model_type, "ForumPost").records { [@ticket] }.user { @creator }
          search(:model_id).value { @forum_post.id }.records { [@ticket] }.user { @creator }
          search(:reason, "foo").records { [@ticket] }.user { @mod }
          search(:status, "approved").records { [@ticket] }.user { @creator }
          search(:creator_id).value { @creator.id }.records { [@ticket] }.user { @creator }
          search(:creator_name).value { @creator.name }.records { [@ticket] }.user { @creator }
          search(:ip_addr, "127.0.0.2").records { [@ticket] }.user { @admin }
          search(:handler_id).value { @handler.id }.records { [@ticket] }.user { @mod }
          search(:handler_name).value { @handler.name }.records { [@ticket] }.user { @mod }
          search(:handler_ip_addr, "127.0.0.3").records { [@ticket] }.user { @admin }
          search(:claimant_id).value { @claimant.id }.records { [@ticket] }.user { @mod }
          search(:claimant_name).value { @claimant.name }.records { [@ticket] }.user { @mod }
          search(:accused_id).value { @accused.id }.records { [@ticket] }.user { @mod }
          search(:accused_name).value { @accused.name }.records { [@ticket] }.user { @mod }
          search.shared.records { [@ticket] }.user { @creator }
        end
      end
    end

    context("update action") do
      setup do
        @ticket = create(:ticket, creator: @reporter, model: create(:comment))
      end

      should("send a new dmail if the status is changed") do
        assert_difference("Dmail.count", 2) do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { status: "approved", message: "abc" } })
        end
      end

      should("add a new ticket message") do
        assert_difference("TicketMessage.count", 1) do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { message: "abc" } })
        end

        assert_equal("abc", @ticket.ticket_messages.last.body)
        assert_equal(@admin.id, @ticket.ticket_messages.last.creator_id)
      end

      should("send a new dmail if send_update_dmail is set") do
        assert_no_difference("Dmail.count") do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { message: "abc" } })
        end

        assert_difference("Dmail.count", 2) do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { message: "def", send_update_dmail: true } })
        end
      end

      should("allow an empty message") do
        assert_no_difference("TicketMessage.count") do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { status: "approved", message: "" } })
        end

        assert_equal("approved", @ticket.reload.status)
      end

      should("reject a message that's present but too short") do
        assert_no_changes("@ticket.reload.status") do
          put_auth(ticket_path(@ticket), @admin, params: { ticket: { status: "approved", message: "a" } })
        end
      end

      should("still display existing messages after a failed update") do
        create(:ticket_message, ticket: @ticket, creator: @reporter, body: "existing message body")

        put_auth(ticket_path(@ticket), @admin, params: { ticket: { status: "approved", message: "a" } })

        assert_includes(response.body, "existing message body")
      end

      should("let a moderator lock the ticket without a message") do
        put_auth(ticket_path(@ticket), @admin, params: { ticket: { is_locked: true } })

        assert_predicate(@ticket.reload, :is_locked?)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).put { ticket_path(@ticket) }.params { { ticket: { message: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::MODERATOR).json.put { ticket_path(@ticket) }.params { { ticket: { message: SecureRandom.hex(6) } } }
        end
      end
    end

    context("ticket messages controller") do
      setup do
        @ticket = create(:ticket, creator: @reporter, model: create(:comment))
      end

      should("let the reporter reply to their own ticket") do
        assert_difference("TicketMessage.count", 1) do
          post_auth(ticket_messages_path(@ticket), @reporter, params: { ticket_message: { body: "more info" } })
        end

        assert_equal("more info", @ticket.ticket_messages.last.body)
        assert_equal(@reporter.id, @ticket.ticket_messages.last.creator_id)
      end

      should("let a moderator reply without changing status") do
        assert_difference("TicketMessage.count", 1) do
          post_auth(ticket_messages_path(@ticket), @admin, params: { ticket_message: { body: "looking into it" } })
        end
      end

      should("notify the reporter when staff replies") do
        assert_difference("Dmail.count", 2) do
          post_auth(ticket_messages_path(@ticket), @admin, params: { ticket_message: { body: "looking into it" } })
        end
      end

      should("notify the claimant when the reporter replies") do
        @ticket.claim!(@admin)

        assert_difference("Dmail.count", 2) do
          post_auth(ticket_messages_path(@ticket), @reporter, params: { ticket_message: { body: "more info" } })
        end
      end

      should("let any moderator reply even if the ticket is claimed by someone else") do
        mod2 = create(:moderator_user)
        @ticket.claim!(@admin)

        assert_difference("TicketMessage.count", 1) do
          post_auth(ticket_messages_path(@ticket), mod2, params: { ticket_message: { body: "chiming in" } })
        end

        assert_response(:redirect)
      end

      should("notify both the creator and claimant when a different moderator replies") do
        mod2 = create(:moderator_user)
        @ticket.claim!(@admin)

        assert_difference("Dmail.count", 4) do
          post_auth(ticket_messages_path(@ticket), mod2, params: { ticket_message: { body: "chiming in" } })
        end
      end

      should("only notify the creator when the claimant themselves replies") do
        @ticket.claim!(@admin)

        assert_difference("Dmail.count", 2) do
          post_auth(ticket_messages_path(@ticket), @admin, params: { ticket_message: { body: "still looking into it" } })
        end
      end

      should("not let an unrelated user reply") do
        assert_no_difference("TicketMessage.count") do
          post_auth(ticket_messages_path(@ticket), @user, params: { ticket_message: { body: "more info" } })
        end

        assert_response(:forbidden)
      end

      should("respond with the created message as json") do
        post_auth(ticket_messages_path(@ticket, format: :json), @reporter, params: { ticket_message: { body: "more info" } })

        assert_response(:success)
        assert_equal("more info", response.parsed_body["body"])
      end

      should("respond with json errors when the message is invalid") do
        post_auth(ticket_messages_path(@ticket, format: :json), @reporter, params: { ticket_message: { body: "" } })

        assert_response(:unprocessable_entity)
      end

      should("list the ticket's messages") do
        create(:ticket_message, ticket: @ticket, creator: @reporter, body: "first reply")
        create(:ticket_message, ticket: @ticket, creator: @admin, body: "second reply")

        get_auth(ticket_messages_path(@ticket, format: :json), @reporter)

        assert_response(:success)
        assert_equal(["first reply", "second reply"], response.parsed_body.map { |m| m["body"] })
      end

      should("not respond to html") do
        get_auth(ticket_messages_path(@ticket), @reporter)

        assert_response(:not_acceptable)
      end

      should("paginate the ticket's messages") do
        create_list(:ticket_message, 3, ticket: @ticket, creator: @reporter)

        get_auth(ticket_messages_path(@ticket, format: :json, limit: 2), @reporter)

        assert_response(:success)
        assert_equal(2, response.parsed_body.length)
      end

      should("not let an unrelated user list messages") do
        get_auth(ticket_messages_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("let anyone who can view the ticket list its messages") do
        artist_ticket = create(:ticket, creator: @reporter, model: create(:artist))

        get_auth(ticket_messages_path(artist_ticket, format: :json), @janitor)

        assert_response(:success)
      end

      should("not let a janitor create a message just because they can view the ticket") do
        artist_ticket = create(:ticket, creator: @reporter, model: create(:artist))

        assert_no_difference("TicketMessage.count") do
          post_auth(ticket_messages_path(artist_ticket), @janitor, params: { ticket_message: { body: "more info" } })
        end

        assert_response(:forbidden)
      end

      should("reopen a resolved ticket when the creator replies") do
        @ticket.update_column(:status, "approved")

        post_auth(ticket_messages_path(@ticket), @reporter, params: { ticket_message: { body: "wait, it's not fixed" } })

        assert_equal("pending", @ticket.reload.status)
      end

      should("not reopen a resolved ticket when a moderator replies") do
        @ticket.update_column(:status, "approved")

        post_auth(ticket_messages_path(@ticket), @admin, params: { ticket_message: { body: "looking into it" } })

        assert_equal("approved", @ticket.reload.status)
      end

      should("not reopen a locked ticket when the creator replies") do
        @ticket.update_columns(status: "approved", is_locked: true)

        post_auth(ticket_messages_path(@ticket), @reporter, params: { ticket_message: { body: "wait, it's not fixed" } })

        assert_equal("approved", @ticket.reload.status)
      end

      should("let an admin delete a message") do
        message = create(:ticket_message, ticket: @ticket, creator: @reporter)

        assert_difference("TicketMessage.count", -1) do
          delete_auth(ticket_message_path(@ticket, message), @admin)
        end
      end

      should("not let a moderator delete a message") do
        message = create(:ticket_message, ticket: @ticket, creator: @reporter)

        assert_no_difference("TicketMessage.count") do
          delete_auth(ticket_message_path(@ticket, message), create(:moderator_user))
        end

        assert_response(:forbidden)
      end

      should("not let the creator delete their own message") do
        message = create(:ticket_message, ticket: @ticket, creator: @reporter)

        assert_no_difference("TicketMessage.count") do
          delete_auth(ticket_message_path(@ticket, message), @reporter)
        end

        assert_response(:forbidden)
      end
    end

    context("for an artist ticket") do
      setup do
        @content = create(:artist, creator: @bad_actor)
      end

      should("allow reporting artists") do
        assert_ticket_create_permissions([[@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("render the new ticket form") do
        get_auth(new_ticket_path(ticket: { model_id: @content.id, model_type: "Artist" }), @user)

        assert_response(:success)
      end

      should("restrict access to users") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
      end
    end

    context("for a character ticket") do
      setup do
        @content = create(:character, creator: @bad_actor)
      end

      should("allow reporting characters") do
        assert_ticket_create_permissions([[@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("render the new ticket form") do
        get_auth(new_ticket_path(ticket: { model_id: @content.id, model_type: "Character" }), @user)

        assert_response(:success)
      end
    end

    context("for a comment ticket") do
      setup do
        @content = create(:comment, creator: @bad_actor)
      end

      should("restrict reporting") do
        assert_ticket_create_permissions([[@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
        @content.update_columns(is_hidden: true)

        assert_ticket_create_permissions([[@user, false], [@janitor, false], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:forbidden)
      end
    end

    context("for a dmail ticket") do
      setup do
        @content = create(:dmail, from: @bad_actor, to: @reporter, owner: @reporter)
      end

      should("disallow reporting dmails you did not recieve") do
        assert_ticket_create_permissions([[@reporter, true], [@user, false], [@janitor, false], [@admin, false], [@bad_actor, false]], model: @content)
      end

      should("restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @reporter)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @admin)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:forbidden)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
        get_auth(ticket_path(@ticket), @bad_actor)

        assert_response(:forbidden)
      end
    end

    context("for a forum ticket") do
      setup do
        @content = create(:forum_topic, creator: @bad_actor).original_post
      end

      should("restrict reporting") do
        assert_ticket_create_permissions([[@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
        @content.update_columns(is_hidden: true)

        assert_ticket_create_permissions([[@janitor, false], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @admin)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @reporter)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:forbidden)
      end
    end

    context("for a pool ticket") do
      setup do
        @content = create(:pool, creator: @bad_actor)
      end

      should("allow reporting pools") do
        assert_ticket_create_permissions([[@reporter, true], [@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access to users") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
      end
    end

    context("for a post ticket") do
      setup do
        @content = create(:post, uploader: @bad_actor)
      end

      should("allow reports") do
        assert_ticket_create_permissions([[@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("not restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
      end
    end

    context("for a post set ticket") do
      setup do
        @content = create(:post_set, is_public: true, creator: @bad_actor)
      end

      should("disallow reporting sets you can't see") do
        assert_ticket_create_permissions([[@reporter, true], [@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
        @content.update_columns(is_public: false)

        assert_ticket_create_permissions([[@reporter, false], [@user, false], [@janitor, false], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:forbidden)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end
    end

    context("for a tag ticket") do
      setup do
        @content = create(:tag, creator: @bad_actor)
      end

      should("allow reporting tags") do
        assert_ticket_create_permissions([[@reporter, true], [@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access to users") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
      end
    end

    context("for a user ticket") do
      setup do
        @content = create(:user, resolvable: false)
      end

      should("allow reporting users") do
        assert_ticket_create_permissions([[@reporter, true], [@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @reporter)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @admin)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:forbidden)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors for commendations") do
        @ticket = create(:ticket, creator: @reporter, model: @content, report_type: "commendation")
        get_auth(ticket_path(@ticket), @reporter)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @admin)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors for janitor created tickets") do
        @janitor2 = create(:janitor_user)
        @ticket = create(:ticket, creator: @janitor2, model: @content)
        get_auth(ticket_path(@ticket), @janitor2)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @admin)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end
    end

    context("for a wiki page ticket") do
      setup do
        @content = create(:wiki_page, creator: @bad_actor)
      end

      should("allow reporting wiki pages") do
        assert_ticket_create_permissions([[@reporter, true], [@user, true], [@janitor, true], [@admin, true], [@bad_actor, true]], model: @content)
      end

      should("restrict access to users") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @user)

        assert_response(:forbidden)
      end

      should("not restrict access to janitors") do
        @ticket = create(:ticket, creator: @reporter, model: @content)
        get_auth(ticket_path(@ticket), @janitor)

        assert_response(:success)
      end
    end
  end
end

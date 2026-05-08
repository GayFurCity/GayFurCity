# frozen_string_literal: true

require("test_helper")

class NotesControllerTest < ActionDispatch::IntegrationTest
  context("The notes controller") do
    setup do
      @user = create(:user)
      @post = create(:post)
      @note = create(:note, body: "000", post: @post)
    end

    context("index action") do
      should("list all notes") do
        get(notes_path)

        assert_response(:success)
      end

      should("list all notes (with search)") do
        params = {
          group_by: "note",
          search:   {
            body_matches:    "000",
            is_active:       true,
            post_id:         @note.post_id,
            post_tags_match: @note.post.tag_array.first,
            creator_name:    @note.creator_name,
            creator_id:      @note.creator_id,
          },
        }

        get(notes_path, params: params)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(notes_path, user) }
      end

      context("search parameters") do
        subject { notes_path }
        setup do
          NoteVersion.delete_all
          Note.delete_all
          @creator = create(:user)
          @admin = create(:admin_user)
          @post = create(:post, tag_string: "foo")
          @note = create(:note, creator: @creator, creator_ip_addr: "127.0.0.2", post: @post, body: "bar", is_active: true)
        end

        assert_search_param(:body_matches, "bar", -> { [@note] })
        assert_search_param(:is_active, "true", -> { [@note] })
        assert_search_param(:post_id, -> { @post.id }, -> { [@note] })
        assert_search_param(:post_tags_match, "foo", -> { [@note] })
        assert_search_param(:post_note_updater_id, -> { @creator.id }, -> { [@note] })
        assert_search_param(:post_note_updater_name, -> { @creator.name }, -> { [@note] })
        assert_search_param(:creator_id, -> { @creator.id }, -> { [@note] })
        assert_search_param(:creator_name, -> { @creator.name }, -> { [@note] })
        assert_search_param(:post_id, -> { @post.id }, -> { [@note] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@note] }, -> { @admin })
        assert_shared_search_params(-> { [@note] })
      end
    end

    context("show action") do
      should("render") do
        get(note_path(@note), params: { format: "json" })

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS, success_response: :redirect, anonymous_response: :redirect) { |user| get_auth(note_path(@note), user) }
      end
    end

    context("create action") do
      should("create a note") do
        assert_difference("Note.count", 1) do
          post_auth(notes_path, @user, params: { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id }, format: :json })
        end
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
          @admin = create(:admin_user)
        end

        should("prevent edits when the editors level is lower") do
          post_auth(notes_path, @user, params: { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id }, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          post_auth(notes_path, @admin, params: { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id }, format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(notes_path, user, params: { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id } }) }
      end
    end

    context("update action") do
      should("update a note") do
        put_auth(note_path(@note), @user, params: { note: { body: "xyz" } })

        assert_equal("xyz", @note.reload.body)
      end

      should("not allow changing the post id to another post") do
        @other = create(:post)
        put_auth(note_path(@note), @user, params: { format: "json", id: @note.id, note: { post_id: @other.id } })

        assert_not_equal(@other.id, @note.reload.post_id)
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
          @admin = create(:admin_user)
        end

        should("prevent edits when the editors level is lower") do
          put_auth(note_path(@note), @user, params: { note: { body: "xyz" }, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          put_auth(note_path(@note), @admin, params: { note: { body: "xyz" }, format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(note_path(@note), user, params: { note: { body: "xyz" } }) }
      end
    end

    context("destroy action") do
      should("destroy a note") do
        delete_auth(note_path(@note), @user)

        assert_not(@note.reload.is_active?)
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
          @admin = create(:admin_user)
        end

        should("prevent edits when the editors level is lower") do
          delete_auth(note_path(@note), @user, params: { format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          delete_auth(note_path(@note), @admin, params: { format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| delete_auth(note_path(@note), user) }
      end
    end

    context("revert action") do
      setup do
        travel_to(1.day.from_now) do
          @note.update_with(@user, body: "111")
        end
        travel_to(2.days.from_now) do
          @note.update_with(@user, body: "222")
        end
      end

      should("revert to a previous version") do
        put_auth(revert_note_path(@note), @user, params: { version_id: @note.versions.first.id })

        assert_equal("000", @note.reload.body)
      end

      should("not allow reverting to a previous version of another note") do
        @note2 = create(:note, body: "note 2")
        put_auth(revert_note_path(@note), @user, params: { version_id: @note2.versions.first.id })

        assert_not_equal(@note.reload.body, @note2.body)
        assert_response(:missing)
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
          @admin = create(:admin_user)
        end

        should("prevent edits when the editors level is lower") do
          put_auth(revert_note_path(@note), @user, params: { version_id: @note.versions.first.id, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          put_auth(revert_note_path(@note), @admin, params: { version_id: @note.versions.first.id, format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(revert_note_path(@note), user, params: { version_id: @note.versions.first.id }) }
      end
    end
  end
end

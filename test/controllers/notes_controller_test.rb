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

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(notes_path)
          access.gte(User::Levels::ANONYMOUS).json.get(notes_path)
        end
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

        asserts do
          search(:body_matches, "bar").records { [@note] }
          search(:is_active, "true").records { [@note] }
          search(:post_id).value { @post.id }.records { [@note] }
          search(:post_tags_match, "foo").records { [@note] }
          search(:post_note_updater_id).value { @creator.id }.records { [@note] }
          search(:post_note_updater_name).value { @creator.name }.records { [@note] }
          search(:creator_id).value { @creator.id }.records { [@note] }
          search(:creator_name).value { @creator.name }.records { [@note] }
          search(:ip_addr, "127.0.0.2").records { [@note] }.user { @admin }
          search.shared.records { [@note] }
        end
      end
    end

    context("show action") do
      should("render") do
        get(note_path(@note), params: { format: "json" })

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { note_path(@note) }.success(:redirect).anonymous(:redirect)
          access.gte(User::Levels::ANONYMOUS).json.get { note_path(@note) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(notes_path).params { { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(notes_path).params { { note: { x: 0, y: 0, width: 10, height: 10, body: "abc", post_id: @post.id } } }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { note_path(@note) }.params({ note: { body: "xyz" } }).success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { note_path(@note) }.params({ note: { body: "xyz" } })
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).delete { note_path(@note) }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.delete { note_path(@note) }.success(:no_content)
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { revert_note_path(@note) }.params { { version_id: @note.versions.first.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { revert_note_path(@note) }.params { { version_id: @note.versions.first.id } }
        end
      end
    end
  end
end

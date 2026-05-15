# frozen_string_literal: true

require("test_helper")

module Notes
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The note versions controller") do
      setup do
        @user = create(:user)
      end

      context("index action") do
        setup do
          @note = create(:note, creator: @user)
          @user2 = create(:user)

          @note.update_with(@user2, body: "1 2")

          @note.update_with(@user, body: "1 2 3")
        end

        should("list all versions") do
          get(note_versions_path)

          assert_response(:success)
        end

        should("list all versions that match the search criteria") do
          get(note_versions_path, params: { search: { updater_id: @user2.id } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(note_versions_path)
          end
        end

        context("search parameters") do
          subject { note_versions_path }
          setup do
            NoteVersion.delete_all
            Note.delete_all
            @updater = create(:user)
            @admin = create(:admin_user)
            @note = create(:note, creator: @updater, updater_ip_addr: "127.0.0.2", is_active: true, body: "foo")
            @note_version = @note.versions.first
          end

          asserts do
            search(:post_id).value { @note.post.id }.records { [@note_version] }
            search(:note_id).value { @note.id }.records { [@note_version] }
            search(:is_active, "true").records { [@note_version] }
            search(:body_matches, "foo").records { [@note_version] }
            search(:updater_id).value { @updater.id }.records { [@note_version] }
            search(:updater_name).value { @updater.name }.records { [@note_version] }
            search(:ip_addr, "127.0.0.2").records { [@note_version] }.user { @admin }
            search.shared.records { [@note_version] }
          end
        end
      end
    end
  end
end

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

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(note_versions_path, user) }
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

          assert_search_param(:post_id, -> { @note.post.id }, -> { [@note_version] })
          assert_search_param(:note_id, -> { @note.id }, -> { [@note_version] })
          assert_search_param(:is_active, "true", -> { [@note_version] })
          assert_search_param(:body_matches, "foo", -> { [@note_version] })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@note_version] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@note_version] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@note_version] }, -> { @admin })
          assert_shared_search_params(-> { [@note_version] })
        end
      end
    end
  end
end

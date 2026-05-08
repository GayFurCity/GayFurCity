# frozen_string_literal: true

require("test_helper")

module BulkUpdateRequests
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The bulk update request versions controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
      end

      context("index action") do
        setup do
          @user2 = create(:user, created_at: 2.weeks.ago)
          @user3 = create(:user, created_at: 2.weeks.ago)
          @bulk_update_request = create(:bulk_update_request, creator: @user)
          @bulk_update_request.update_with!(@user2, script: "alias bar -> foo")
          @bulk_update_request.update_with!(@user3, script: "alias bar -> baz")
          @versions = @bulk_update_request.versions
        end

        should("list all versions") do
          get_auth(bulk_update_request_versions_path, @user)

          assert_response(:success)
          assert_select("#bulk-update-request-version-#{@versions[0].id}")
          assert_select("#bulk-update-request-version-#{@versions[1].id}")
          assert_select("#bulk-update-request-version-#{@versions[2].id}")
        end

        should("list all versions that match the search criteria") do
          get_auth(bulk_update_request_versions_path, @user, params: { search: { updater_id: @user2.id } })

          assert_response(:success)
          assert_select("#bulk-update-request-version-#{@versions[0].id}", false)
          assert_select("#bulk-update-request-version-#{@versions[1].id}")
          assert_select("#bulk-update-request-version-#{@versions[2].id}", false)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(bulk_update_request_versions_path, user) }
        end

        context("search parameters") do
          subject { bulk_update_request_versions_path }
          setup do
            BulkUpdateRequestVersion.delete_all
            BulkUpdateRequest.delete_all
            @updater = create(:user)
            @admin = create(:admin_user)
            @bulk_update_request = create(:bulk_update_request, updater: @updater, updater_ip_addr: "127.0.0.2", skip_forum: true)
            @bulk_update_request_version = @bulk_update_request.versions.first
          end

          assert_search_param(:bulk_update_request_id, -> { @bulk_update_request.id }, -> { [@bulk_update_request_version] })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@bulk_update_request_version] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@bulk_update_request_version] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@bulk_update_request_version] }, -> { @admin })
          assert_shared_search_params(-> { [@bulk_update_request_version] })
        end
      end

      context("undo action") do
        setup do
          @bulk_update_request = create(:bulk_update_request, creator: @user)
          @bulk_update_request.update_with(@user, script: "alias foo -> bar")
        end

        should("work") do
          version = @bulk_update_request.versions.first

          assert_match(/\Aalias aaa -> bbb/, version.script)
          put_auth(undo_bulk_update_request_version_path(@bulk_update_request.versions.second), @user)
          @bulk_update_request.reload

          assert_match(/\Aalias aaa -> bbb/, @bulk_update_request.reload.script)
        end

        should("not allow undoing version 1") do
          put_auth(undo_bulk_update_request_version_path(@bulk_update_request.versions.first), @user)

          assert_response(:bad_request)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(undo_bulk_update_request_version_path(@bulk_update_request.versions.second), user) }
        end
      end
    end
  end
end

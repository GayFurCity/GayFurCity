# frozen_string_literal: true

require("test_helper")

module BulkUpdateRequests
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    context("The bulk update request imports controller") do
      setup do
        @owner = create(:owner_user)
      end

      context("index action") do
        setup do
          @import = create(:bulk_update_request_import, creator: @owner)
        end

        should("list imports") do
          get_auth(bulk_update_request_imports_path, @owner)

          assert_response(:success)
        end

        should("filter by status") do
          @failed_import = create(:bulk_update_request_import, creator: @owner)
          @failed_import.update_columns(status: "failed", status_message: "boom")

          get_auth(bulk_update_request_imports_path, @owner, params: { search: { status: "failed" } })

          assert_response(:success)
          assert_select("body", /boom/)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(bulk_update_request_imports_path)
            access.gte(User::Levels::ADMIN).json.get(bulk_update_request_imports_path)
          end
        end

        context("search parameters") do
          subject { bulk_update_request_imports_path }
          setup do
            BulkUpdateRequestImport.delete_all
            TagAlias.delete_all
            TagImplication.delete_all
            @creator = create(:user, ip_addr: "127.0.0.2")
            @updater = create(:user, ip_addr: "127.0.0.3")
            @admin = create(:admin_user)
            @forum_topic = create(:forum_topic)
            @import = create(:bulk_update_request_import, creator: @creator, updater: @updater, status: "pending", script: "alias foo -> bar", forum_topic: @forum_topic)
          end

          asserts do
            search(:status, "pending").records { [@import] }.user { @admin }
            search(:script_matches, "alias").records { [@import] }.user { @admin }
            search(:forum_topic_id).value { @forum_topic.id }.records { [@import] }.user { @admin }
            search(:creator_id).value { @creator.id }.records { [@import] }.user { @admin }
            search(:creator_name).value { @creator.name }.records { [@import] }.user { @admin }
            search(:creator_ip_addr, "127.0.0.2").records { [@import] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@import] }.user { @admin }
            search(:updater_name).value { @updater.name }.records { [@import] }.user { @admin }
            search(:updater_ip_addr, "127.0.0.3").records { [@import] }.user { @admin }
            search.shared.records { [@import] }.user { @admin }
          end
        end
      end

      context("show action") do
        setup do
          @import = create(:bulk_update_request_import, creator: @owner)
        end

        should("redirect to index") do
          get_auth(bulk_update_request_import_path(@import), @owner)

          assert_redirected_to(bulk_update_request_imports_path(search: { id: @import.id }))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get { bulk_update_request_import_path(@import) }.success(:redirect)
            access.gte(User::Levels::OWNER).json.get { bulk_update_request_import_path(@import) }
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_bulk_update_request_import_path, @owner)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get(new_bulk_update_request_import_path)
            access.gte(User::Levels::OWNER).json.get(new_bulk_update_request_import_path)
          end
        end
      end

      context("create action") do
        should("create and queue a valid import") do
          assert_difference("BulkUpdateRequestImport.count", 1) do
            with_inline_jobs do
              post_auth(bulk_update_request_imports_path, @owner, params: { bulk_update_request_import: { script: "category bur_import_create_tag -> general" } })
            end
          end

          @import = BulkUpdateRequestImport.last

          assert_redirected_to(bulk_update_request_import_path(@import))
          assert_equal("completed", @import.status)
        end

        should("not create an import for an invalid script") do
          assert_no_difference("BulkUpdateRequestImport.count") do
            post_auth(bulk_update_request_imports_path, @owner, params: { bulk_update_request_import: { script: "not a real command" } })
          end

          assert_response(:bad_request)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).post(bulk_update_request_imports_path).params { { bulk_update_request_import: { script: "category bur_import_access_tag -> general" } } }.success(:redirect)
            access.gte(User::Levels::OWNER).json.post(bulk_update_request_imports_path).params { { bulk_update_request_import: { script: "category bur_import_access_json_tag -> general" } } }
          end
        end
      end

      context("edit action") do
        setup do
          @pending_import = create(:bulk_update_request_import, creator: @owner)
          @failed_import = create(:bulk_update_request_import, creator: @owner)
          @failed_import.update_columns(status: "failed", status_message: "boom")
        end

        should("render for a failed import") do
          get_auth(edit_bulk_update_request_import_path(@failed_import), @owner)

          assert_response(:success)
        end

        should("not allow editing an import that isn't failed") do
          get_auth(edit_bulk_update_request_import_path(@pending_import), @owner)

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get { edit_bulk_update_request_import_path(@failed_import) }
          end
        end
      end

      context("update action") do
        setup do
          @failed_import = create(:bulk_update_request_import, creator: @owner)
          @failed_import.update_columns(status: "failed", status_message: "boom")
        end

        should("edit the script and re-queue the import") do
          with_inline_jobs do
            patch_auth(bulk_update_request_import_path(@failed_import), @owner, params: { bulk_update_request_import: { script: "category bur_import_update_tag -> general" } })
          end

          assert_redirected_to(new_bulk_update_request_import_path)
          @failed_import.reload

          assert_equal("completed", @failed_import.status)
          assert_equal("category bur_import_update_tag -> general", @failed_import.script)
        end

        should("re-render with an error for a script that's still invalid") do
          patch_auth(bulk_update_request_import_path(@failed_import), @owner, params: { bulk_update_request_import: { script: "not a real command" } })

          assert_response(:bad_request)
          assert_equal("failed", @failed_import.reload.status)
        end

        should("not allow updating an import that isn't failed") do
          @pending_import = create(:bulk_update_request_import, creator: @owner)

          patch_auth(bulk_update_request_import_path(@pending_import), @owner, params: { bulk_update_request_import: { script: "category bur_import_update_denied_tag -> general" } })

          assert_response(:forbidden)
        end

        context("access control") do
          setup { Config.any_instance.stubs(:bur_entry_limit).returns({ User::Levels::ANONYMOUS => 1 }) }

          asserts do
            access.gte(User::Levels::OWNER).patch do |user|
              import = create(:bulk_update_request_import, creator: user)
              import.update_columns(status: "failed")
              bulk_update_request_import_path(import)
            end.params { { bulk_update_request_import: { script: "category bur_import_access_update_tag -> general" } } }.success(:redirect)
            access.gte(User::Levels::OWNER).json.patch do |user|
              import = create(:bulk_update_request_import, creator: user)
              import.update_columns(status: "failed")
              bulk_update_request_import_path(import)
            end.params { { bulk_update_request_import: { script: "category bur_import_access_update_tag -> general" } } }
          end
        end
      end
    end
  end
end

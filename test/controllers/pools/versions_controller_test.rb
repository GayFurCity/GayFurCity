# frozen_string_literal: true

require("test_helper")

module Pools
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The pool versions controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
      end

      context("index action") do
        setup do
          @posts = create_list(:post, 4) # posts must be valid to be added to pools
          @pool = create(:pool, creator: @user)
          @user2 = create(:user, created_at: 2.weeks.ago)
          @user3 = create(:user, created_at: 2.weeks.ago)

          @pool.update_with!(@user2, post_ids: @posts.first(2).pluck(:id))
          @pool.update_with!(@user3, post_ids: @posts.pluck(:id))

          @versions = @pool.versions
        end

        should("list all versions") do
          assert_equal(@posts.pluck(:id), @pool.reload.post_ids)
          get_auth(pool_versions_path, @user)
          assert_response(:success)
          assert_select("#pool-version-#{@versions[0].id}")
          assert_select("#pool-version-#{@versions[1].id}")
          assert_select("#pool-version-#{@versions[2].id}")
        end

        should("list all versions that match the search criteria") do
          get_auth(pool_versions_path, @user, params: { search: { updater_id: @user2.id } })
          assert_response(:success)
          assert_select("#pool-version-#{@versions[0].id}", false)
          assert_select("#pool-version-#{@versions[1].id}")
          assert_select("#pool-version-#{@versions[2].id}", false)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(pool_versions_path, user) }
        end

        context("search parameters") do
          subject { pool_versions_path }
          setup do
            PoolVersion.delete_all
            Pool.delete_all
            @updater = create(:user)
            @admin = create(:admin_user)
            @pool = create(:pool, creator: @updater, creator_ip_addr: "127.0.0.2", name: "foo", description: "bar")
            @pool_version = @pool.versions.first
          end

          assert_search_param(:pool_id, -> { @pool.id }, -> { [@pool_version] })
          assert_search_param(:name_matches, "foo", -> { [@pool_version] })
          assert_search_param(:description_matches, "bar", -> { [@pool_version] })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@pool_version] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@pool_version] })
          assert_shared_search_params(-> { [@pool_version] })
        end
      end

      context("undo action") do
        setup do
          @posts = create_list(:post, 2)
          @pool = create(:pool, post_ids: [@posts.first.id])
          @pool.update_with(@user, post_ids: [@posts.first.id, @posts.second.id])
        end

        should("work") do
          version = @pool.versions.first
          assert_equal([@posts.first.id], version.post_ids)
          put_auth(undo_pool_version_path(@pool.versions.second), @user)
          @pool.reload
          assert_equal([@posts.first.id], @pool.post_ids)
        end

        should("not allow undoing version 1") do
          put_auth(undo_pool_version_path(@pool.versions.first), @user)
          assert_response(:bad_request)
        end

        should("restrict access") do
          GayFurCity.config.stubs(:disable_age_checks).returns(true)
          assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(undo_pool_version_path(@pool.versions.second), user) }
        end
      end
    end
  end
end

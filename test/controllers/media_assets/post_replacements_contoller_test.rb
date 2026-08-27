# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class PostReplacementsControllerTest < ActionDispatch::IntegrationTest
    context("The post replacement media assets controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @user2 = create(:user)
        @janitor = create(:janitor_user)
        @admin = create(:admin_user)
        @part1 = file_fixture("test-512x512.webm.part1")
        @part2 = file_fixture("test-512x512.webm.part2")
        @combined = file_fixture("test-512x512.webm")
        @media_asset = create(:post_replacement_media_asset, creator: @user, checksum: MediaAsset.md5(@combined))
      end

      context("index action") do
        should("render") do
          get_auth(post_replacement_media_assets_path, @user)

          assert_response(:success)
        end

        should("list created media assets") do
          get_auth(post_replacement_media_assets_path, @user)

          assert_response(:success)
          assert_select("#post-replacement-media-asset-#{@media_asset.id}", count: 1)
        end

        should("list all media assets for staff") do
          get_auth(post_replacement_media_assets_path, @janitor)

          assert_response(:success)
          assert_select("#post-replacement-media-asset-#{@media_asset.id}", count: 1)
        end

        should("not list media assets created by others") do
          get_auth(post_replacement_media_assets_path, @user2)

          assert_response(:success)
          assert_select("#post-replacement-media-asset-#{@media_asset.id}", count: 0)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(post_replacement_media_assets_path)
            access.gte(User::Levels::MEMBER).json.get(post_replacement_media_assets_path)
          end
        end

        context("search parameters") do
          subject { post_replacement_media_assets_path }
          setup do
            PostReplacementMediaAsset.delete_all
            @janitor = create(:janitor_user)
            @creator = create(:user, created_at: 2.weeks.ago)
            @admin = create(:admin_user)
            @post = create(:post)
            @post_replacement = create(:jpg_replacement, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2")
            @media_asset = @post_replacement.media_asset
            @media_asset.update(status_message: "foo")
          end

          asserts do
            search(:checksum, "ecef68c44edb8a0d6a3070b5f8e8ee76").records { [@media_asset] }.user { @janitor }
            search(:md5, "ecef68c44edb8a0d6a3070b5f8e8ee76").records { [@media_asset] }.user { @janitor }
            search(:file_ext, "jpg").records { [@media_asset] }.user { @janitor }
            search(:pixel_hash, "01cb481ec7730b7cfced57ffa5abd196").records { [@media_asset] }.user { @janitor }
            search(:status, "active").records { [@media_asset] }.user { @janitor }
            search(:status_message_matches, "foo").records { [@media_asset] }.user { @janitor }
            search(:post_replacement_id).value { @post_replacement.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_id).value { @creator.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_name).value { @creator.name }.records { [@media_asset] }.user { @janitor }
            search(:ip_addr, "127.0.0.2").records { [@media_asset] }.user { @admin }
            search.shared.records { [@media_asset] }.user { @janitor }
          end
        end
      end

      context("append action") do
        should("work") do
          put_auth(append_post_replacement_media_asset_path(@media_asset), @user, params: { post_replacement_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@combined.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@combined.to_s))
        end

        should("work across multiple requests") do
          put_auth(append_post_replacement_media_asset_path(@media_asset), @user, params: { post_replacement_media_asset: { chunk_id: 1, data: file_fixture_upload(@part1) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@part1.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@part1.to_s))

          put_auth(append_post_replacement_media_asset_path(@media_asset), @user, params: { post_replacement_media_asset: { chunk_id: 2, data: file_fixture_upload(@part2) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@combined.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@combined.to_s))
        end

        should("not allow invalid chunk ids") do
          put_auth(append_post_replacement_media_asset_path(@media_asset), @user, params: { post_replacement_media_asset: { chunk_id: 2, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["unexpected: 2, expected: 1"], @response.parsed_body.dig("errors", "chunk_id"))
        end

        should("not allow files that are too large") do
          AdminConfig.any_instance.stubs(:max_file_size).returns(0)
          AdminConfig.any_instance.stubs(:max_file_sizes).returns({ "jpg" => 0 })
          put_auth(append_post_replacement_media_asset_path(@media_asset), @user, params: { post_replacement_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal("failed: File size is too large. Maximum allowed for this file type is 0 Bytes", @response.parsed_body["message"])
          assert_equal("failed", @media_asset.reload.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).json.put { |user| append_post_replacement_media_asset_path(create(:post_replacement_media_asset, creator: user)) }.params { { post_replacement_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) } } }
          end
        end
      end

      context("finalize action") do
        should("work") do
          @media_asset.append_chunk!(1, @combined.open)

          assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
            put_auth(finalize_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

            assert_response(:success)
          end
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert_equal("34dd2489f7aaa9e57eda1b996ff26ff7", @media_asset.md5)
          assert_nil(@media_asset.pixel_hash)
          assert_equal(512, @media_asset.image_width)
          assert_equal(512, @media_asset.image_height)
          assert_equal(12_345, @media_asset.file_size)
          assert_equal("webm", @media_asset.file_ext)
          assert_in_delta(0.48, @media_asset.duration)
          assert_equal(24, @media_asset.framecount)
          assert_not(@media_asset.is_animated_png?)
          assert_not(@media_asset.is_animated_gif?)
        end

        should("work with multiple appends") do
          @media_asset.append_chunk!(1, @part1.open)
          @media_asset.append_chunk!(2, @part2.open)

          assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
            put_auth(finalize_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

            assert_response(:success)
          end
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert_equal("34dd2489f7aaa9e57eda1b996ff26ff7", @media_asset.md5)
          assert_nil(@media_asset.pixel_hash)
          assert_equal(512, @media_asset.image_width)
          assert_equal(512, @media_asset.image_height)
          assert_equal(12_345, @media_asset.file_size)
          assert_equal("webm", @media_asset.file_ext)
          assert_in_delta(0.48, @media_asset.duration)
          assert_equal(24, @media_asset.framecount)
          assert_not(@media_asset.is_animated_png?)
          assert_not(@media_asset.is_animated_gif?)
        end

        should("mark replacement pending") do
          @media_asset.create_post_replacement!(post: create(:post), creator: @user, creator_ip_addr: "127.0.0.1", reason: "testing")
          @media_asset.append_chunk!(1, @combined.open)

          assert_equal("uploading", @media_asset.reload_post_replacement.status)

          put_auth(finalize_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          @post_replacement = @media_asset.post_replacement

          assert_equal("pending", @post_replacement.status)
          assert_equal({ "success" => true, "location" => post_path(@post_replacement.post_id), "post_id" => @post_replacement.post_id, "post_replacement_id" => @post_replacement.id }, @response.parsed_body)
        end

        should("not allow finalizing empty media assets") do
          put_auth(finalize_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["Upload is empty"], @response.parsed_body.dig("errors", "base"))
        end

        context("access control") do
          asserts do
            access do |builder|
              builder.gte(User::Levels::MEMBER).json.put do |user|
                asset = create(:post_replacement_media_asset, creator: user, checksum: MediaAsset.md5(@combined.to_s))
                asset.append_chunk!(1, @combined.open)
                finalize_post_replacement_media_asset_path(asset)
              end
            end
          end
        end
      end

      context("cancel action") do
        should("work") do
          put_auth(cancel_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
        end

        should("remove file") do
          @media_asset.append_chunk!(1, @combined.open)

          assert_path_exists(@media_asset.tempfile_path)

          put_auth(cancel_post_replacement_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
          assert_not(File.exist?(@media_asset.tempfile_path))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).json.put { |user| cancel_post_replacement_media_asset_path(create(:post_replacement_media_asset, creator: user)) }
          end
        end
      end
    end
  end
end

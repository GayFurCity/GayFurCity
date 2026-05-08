# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class UploadsControllerTest < ActionDispatch::IntegrationTest
    context("The upload media assets controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @user2 = create(:user)
        @janitor = create(:janitor_user)
        @admin = create(:admin_user)
        @part1 = file_fixture("test.jpg.part1")
        @part2 = file_fixture("test.jpg.part2")
        @combined = file_fixture("test.jpg")
        @media_asset = create(:upload_media_asset, creator: @user, checksum: MediaAsset.md5(@combined))
      end

      context("index action") do
        should("render") do
          get_auth(upload_media_assets_path, @user)

          assert_response(:success)
        end

        should("list created media assets") do
          get_auth(upload_media_assets_path, @user)

          assert_response(:success)
          assert_select("#upload-media-asset-#{@media_asset.id}", count: 1)
        end

        should("list all media assets for staff") do
          get_auth(upload_media_assets_path, @janitor)

          assert_response(:success)
          assert_select("#upload-media-asset-#{@media_asset.id}", count: 1)
        end

        should("not list media assets created by others") do
          get_auth(upload_media_assets_path, @user2)

          assert_response(:success)
          assert_select("#upload-media-asset-#{@media_asset.id}", count: 0)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER) { |user| get_auth(upload_media_assets_path, user) }
        end

        context("search parameters") do
          subject { upload_media_assets_path }
          setup do
            UploadMediaAsset.delete_all
            @janitor = create(:janitor_user)
            @creator = create(:user, created_at: 2.weeks.ago)
            @admin = create(:admin_user)
            @upload = create(:jpg_upload, creator: @creator, creator_ip_addr: "127.0.0.2")
            @media_asset = @upload.media_asset
            @media_asset.update(status_message: "foo")
          end

          assert_search_param(:checksum, "ecef68c44edb8a0d6a3070b5f8e8ee76", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:md5, "ecef68c44edb8a0d6a3070b5f8e8ee76", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:file_ext, "jpg", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:pixel_hash, "01cb481ec7730b7cfced57ffa5abd196", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:status, "active", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:status_message_matches, "foo", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:upload_id, -> { @upload.id }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@media_asset] }, -> { @admin })
          assert_shared_search_params(-> { [@media_asset] }, -> { @janitor })
        end
      end

      context("append action") do
        should("work") do
          put_auth(append_upload_media_asset_path(@media_asset), @user, params: { upload_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@combined.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@combined.to_s))
        end

        should("work across multiple requests") do
          put_auth(append_upload_media_asset_path(@media_asset), @user, params: { upload_media_asset: { chunk_id: 1, data: file_fixture_upload(@part1) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@part1.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@part1.to_s))

          put_auth(append_upload_media_asset_path(@media_asset), @user, params: { upload_media_asset: { chunk_id: 2, data: file_fixture_upload(@part2) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@combined.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@combined.to_s))
        end

        should("not allow invalid chunk ids") do
          put_auth(append_upload_media_asset_path(@media_asset), @user, params: { upload_media_asset: { chunk_id: 2, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["unexpected: 2, expected: 1"], @response.parsed_body.dig("errors", "chunk_id"))
        end

        should("not allow files that are too large") do
          Config.any_instance.stubs(:max_file_size).returns(0)
          Config.any_instance.stubs(:max_file_sizes).returns({ "jpg" => 0 })
          put_auth(append_upload_media_asset_path(@media_asset), @user, params: { upload_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal("failed: File size is too large. Maximum allowed for this file type is 0 Bytes", @response.parsed_body["message"])
          assert_equal("failed", @media_asset.reload.status)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) { |user| put_auth(append_upload_media_asset_path(create(:upload_media_asset, creator: user)), user, params: { upload_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json }) }
        end
      end

      context("finalize action") do
        should("work") do
          @media_asset.append_chunk!(1, @combined.open)
          assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
            put_auth(finalize_upload_media_asset_path(@media_asset), @user, params: { format: :json })

            assert_response(:success)
          end
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @media_asset.md5)
          assert_equal("01cb481ec7730b7cfced57ffa5abd196", @media_asset.pixel_hash)
          assert_equal(500, @media_asset.image_width)
          assert_equal(335, @media_asset.image_height)
          assert_equal(28_086, @media_asset.file_size)
          assert_equal("jpg", @media_asset.file_ext)
          assert_nil(@media_asset.duration)
          assert_nil(@media_asset.framecount)
          assert_not(@media_asset.is_animated_png?)
          assert_not(@media_asset.is_animated_gif?)
        end

        should("work with multiple appends") do
          @media_asset.append_chunk!(1, @part1.open)
          @media_asset.append_chunk!(2, @part2.open)

          assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
            put_auth(finalize_upload_media_asset_path(@media_asset), @user, params: { format: :json })

            assert_response(:success)
          end
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @media_asset.md5)
          assert_equal("01cb481ec7730b7cfced57ffa5abd196", @media_asset.pixel_hash)
          assert_equal(500, @media_asset.image_width)
          assert_equal(335, @media_asset.image_height)
          assert_equal(28_086, @media_asset.file_size)
          assert_equal("jpg", @media_asset.file_ext)
          assert_nil(@media_asset.duration)
          assert_nil(@media_asset.framecount)
          assert_not(@media_asset.is_animated_png?)
          assert_not(@media_asset.is_animated_gif?)
        end

        should("create a post when paired with an upload") do
          Config.any_instance.stubs(:enable_autotagging).returns(false)
          @media_asset.create_upload!(rating: "e", tag_string: "tagme", uploader: @user, uploader_ip_addr: "127.0.0.1")
          @media_asset.append_chunk!(1, @combined.open)

          put_auth(finalize_upload_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert(Post.exists?(upload_media_asset_id: @media_asset.id))
          @post = @media_asset.post

          assert_equal("e", @post.rating)
          assert_equal("tagme", @post.tag_string)
          assert_equal(@user.id, @post.uploader_id)
          assert_equal({ "success" => true, "location" => post_path(@post), "post_id" => @post.id, "upload_id" => @media_asset.upload.id }, @response.parsed_body)
        end

        should("not allow finalizing empty media assets") do
          put_auth(finalize_upload_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["Upload is empty"], @response.parsed_body.dig("errors", "base"))
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) do |user|
            asset = create(:upload_media_asset, creator: user, checksum: MediaAsset.md5(@combined.to_s))
            asset.append_chunk!(1, @combined.open)
            put_auth(finalize_upload_media_asset_path(asset), user, params: { format: :json })
            asset.destroy
          end
        end
      end

      context("cancel action") do
        should("work") do
          put_auth(cancel_upload_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
        end

        should("remove file") do
          @media_asset.append_chunk!(1, @combined.open)

          assert_path_exists(@media_asset.tempfile_path)

          put_auth(cancel_upload_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
          assert_not(File.exist?(@media_asset.tempfile_path))
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) { |user| put_auth(cancel_upload_media_asset_path(create(:upload_media_asset, creator: user)), user, params: { format: :json }) }
        end
      end
    end
  end
end

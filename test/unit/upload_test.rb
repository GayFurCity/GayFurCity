# frozen_string_literal: true

require("test_helper")

class UploadTest < ActiveSupport::TestCase
  include(ActiveJob::TestHelper)

  context("An upload") do
    setup do
      @user = create(:user, created_at: 2.weeks.ago)
    end

    context("from a user that is limited") do
      setup do
        User.any_instance.stubs(:upload_limit).returns(0)
        GayFurCity.config.stubs(:disable_throttles).returns(false)
      end

      should("fail creation") do
        @upload = build(:jpg_upload, tag_string: "", uploader: @user)
        @upload.save

        assert_equal(["You have reached your upload limit"], @upload.errors.full_messages)
      end
    end

    context("From a user that has too many pending uploads") do
      setup do
        Config.any_instance.stubs(:pending_uploads_limit).returns(0)
      end

      should("fail creation") do
        @upload = build(:jpg_upload, tag_string: "", uploader: @user)
        @upload.save

        assert_equal(["You have too many pending uploads. Finish or cancel your existing uploads and try again"], @upload.errors.full_messages)
      end
    end

    should("require a checksum if no file or direct_url is provided") do
      @upload = build(:upload, uploader: @user, upload_media_asset: build(:upload_media_asset, checksum: nil, creator: @user))
      @upload.save

      assert_equal(["Checksum is required unless a file or direct_url is supplied"], @upload.errors.full_messages)
    end

    context("with a source containing unicode characters") do
      should("normalize unicode characters in the source field") do
        source1 = "poke\u0301mon" # pokémon (nfd form)
        source2 = "pok\u00e9mon"  # pokémon (nfc form)
        @upload = create(:jpg_upload, source: source1, uploader: @user)

        assert_equal(source2, @upload.post.source)
      end
    end

    context("without a file or a direct url") do
      should("be pending") do
        @upload = create(:upload, file: nil, direct_url: nil, uploader: @user, upload_media_asset: build(:upload_media_asset, creator: @user))

        assert_equal("pending", @upload.status)
      end
    end

    context("with both a file and direct url") do
      should("prefer the file") do
        file = fixture_file_upload("alpha.png")
        create(:upload_whitelist, pattern: "http://example.com/*")
        CloudflareService.stubs(:ips).returns([])
        stub_request(:get, "http://example.com/alpha.png").to_return(status: 200, body: file.read, headers: { "Content-Type" => "image/png" })
        @upload = create(:upload, file: fixture_file_upload("test.jpg"), direct_url: "http://example.com/alpha.png", uploader: @user, upload_media_asset: build(:upload_media_asset, checksum: nil, creator: @user))

        assert_equal("active", @upload.status)
        assert_equal("jpg", @upload.file_ext)
      end
    end

    should("create a post") do
      @upload = create(:jpg_upload, uploader: @user)

      assert_not_nil(@upload.post)
    end

    context("uploaded as in-progress") do
      should("be in progress if the uploader is permitted") do
        permitted_user = create(:user, created_at: 2.weeks.ago, can_upload_in_progress: true)
        @upload = create(:jpg_upload, uploader: permitted_user, as_in_progress: true, tag_string: create(:artist_tag).name)

        assert_predicate(@upload.post, :is_in_progress?)
        assert_not(@upload.post.is_pending?)
      end

      should("be pending instead if the uploader isn't permitted") do
        @upload = create(:jpg_upload, uploader: @user, as_in_progress: true)

        assert_not(@upload.post.is_in_progress?)
      end
    end

    context("That is AI") do
      should("be flagged") do
        Config.any_instance.stubs(:ai_confidence_threshold).returns(50)
        Config.any_instance.stubs(:flag_ai_posts).returns(true)
        @upload = create(:ai_upload, uploader: @user)
        perform_enqueued_jobs(only: AiCheckJob)
        @post = @upload.post&.reload

        assert_not_nil(@post)
        @flag = @post.flags.flag.by_system.unresolved.first

        assert_not_nil(@flag)
        MediaAsset.is_ai_generated?(@post.file_path) => { score:, reason: }

        assert_equal("AI Score: #{score}\nReason: #{reason}", @flag.note)
      end

      should("be tagged") do
        Config.any_instance.stubs(:ai_confidence_threshold).returns(50)
        Config.any_instance.stubs(:tag_ai_posts).returns(true)
        @upload = create(:ai_upload, uploader: @user)
        perform_enqueued_jobs(only: AiCheckJob)
        @post = @upload.post&.reload

        assert_not_nil(@post)
        assert(@post.has_tag?("ai_generated"))
        assert_match(/ai_generated/, @post.locked_tags)
      end

      should("keep the correct uploader and editor") do
        Config.any_instance.stubs(:ai_confidence_threshold).returns(50)
        Config.any_instance.stubs(:flag_ai_posts).returns(true)
        Config.any_instance.stubs(:tag_ai_posts).returns(true)
        @upload = create(:ai_upload, uploader: @user)
        perform_enqueued_jobs(only: AiCheckJob)
        @post = @upload.post&.reload

        assert_not_nil(@post)
        assert_equal(@user.id, @post.uploader_id)
        assert_equal(@user.id, @post.versions.first.updater_id)
        assert_equal(User.system.id, @post.versions.second.updater_id)
      end
    end
  end
end

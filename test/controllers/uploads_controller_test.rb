# frozen_string_literal: true

require("test_helper")

class UploadsControllerTest < ActionDispatch::IntegrationTest
  context("The uploads controller") do
    setup do
      @user = create(:janitor_user)
    end

    context("new action") do
      should("render") do
        get_auth(new_upload_path, @user)

        assert_response(:success)
      end

      context("when uploads are disabled") do
        setup do
          Security::Lockdown.uploads_min_level = User::Levels::TRUSTED
        end

        teardown do
          Security::Lockdown.uploads_min_level = User::Levels::MEMBER
        end

        should("prevent uploads") do
          get_auth(new_upload_path, create(:user))

          assert_response(:forbidden)
        end

        should("allow uploads for users of the same or higher level") do
          get_auth(new_upload_path, create(:trusted_user, created_at: 2.weeks.ago))

          assert_response(:success)
        end
      end

      context("access control") do
        setup { GayFurCity.config.stubs(:disable_age_checks).returns(true) }

        asserts do
          access.gte(User::Levels::MEMBER).get(new_upload_path)
        end
      end
    end

    context("index action") do
      setup do
        @upload = create(:upload, tag_string: "foo bar")
      end

      should("render") do
        get_auth(uploads_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::JANITOR).get(uploads_path)
          access.gte(User::Levels::JANITOR).json.get(uploads_path)
        end
      end

      context("search parameters") do
        subject { uploads_path }
        setup do
          Upload.delete_all
          @uploader = create(:user, created_at: 2.weeks.ago)
          @janitor = create(:janitor_user)
          @admin = create(:admin_user)
          @parent = create(:post)
          @post = create(:post, uploader: @uploader, uploader_ip_addr: "127.0.0.2", source: "https://google.com", rating: "e", parent_id: @parent.id, tag_string: "tagme")
          @upload = create(:upload, uploader: @uploader, uploader_ip_addr: "127.0.0.2", source: "https://google.com", rating: "e", parent_id: @parent.id, tag_string: "tagme", backtrace: "foo", post: @post)
        end

        asserts do
          search(:source, "https://google.com").records { [@upload] }.user { @janitor }
          search(:source_matches, "https://google.com").records { [@upload] }.user { @janitor }
          search(:rating, "e").records { [@upload] }.user { @janitor }
          search(:parent_id).value { @parent.id }.records { [@upload] }.user { @janitor }
          search(:post_id).value { @post.id }.records { [@upload] }.user { @janitor }
          search(:status, "active").records { [@upload] }.user { @janitor }
          search(:ip_addr, "127.0.0.2").records { [@upload] }.user { @admin }
          search(:has_post, "true").records { [@upload] }.user { @janitor }
          search(:post_tags_match, "tagme").records { [@upload] }.user { @janitor }
          search(:backtrace, "foo").records { [@upload] }.user { @janitor }
          search(:tag_string, "tagme").records { [@upload] }.user { @janitor }
          search(:uploader_id).value { @uploader.id }.records { [@upload] }.user { @janitor }
          search(:uploader_name).value { @uploader.name }.records { [@upload] }.user { @janitor }
          search.shared.records { [@upload] }.user { @janitor }
        end
      end
    end

    context("show action") do
      setup do
        @pending = create(:upload)
        @upload = create(:jpg_upload)
      end

      should("render") do
        get_auth(upload_path(@pending), @user)

        assert_response(:success)
      end

      should("redirect if post exists") do
        get_auth(upload_path(@upload), @user)

        assert_redirected_to(post_path(@upload.post))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::JANITOR).get { upload_path(@pending) }
          access.gte(User::Levels::JANITOR).json.get { upload_path(@pending) }
        end
      end
    end

    context("create action") do
      should("create a new upload") do
        assert_difference("Upload.count", 1) do
          file = fixture_file_upload("test.jpg")
          post_auth(uploads_path, @user, params: { upload: { file: file, tag_string: "aaa", rating: "q", source: "aaa" }, format: :json })

          assert_response(:success)
        end
      end

      should("autoapprove uploads by approvers") do
        assert_difference("Upload.count", 1) do
          file = fixture_file_upload("test.jpg")
          post_auth(uploads_path, create(:janitor_user), params: { upload: { file: file, tag_string: "aaa", rating: "q", source: "aaa" }, format: :json })

          assert_response(:success)
        end
        assert_not(Post.last.is_pending?)
        assert_not(@user.notifications.post_approve.exists?)
      end

      context("with a previously destroyed post") do
        setup do
          @admin = create(:admin_user)
          @upload = create(:jpg_upload)
          @upload.media_asset.expunge!(@admin)
        end

        should("fail and create ticket") do
          assert_difference({ "Post.count" => 0, "Ticket.count" => 1 }) do
            assert_enqueued_jobs(1, only: NotifyExpungedMediaAssetReuploadJob) do
              file = fixture_file_upload("test.jpg")
              post_auth(uploads_path, @user, params: { upload: { file: file, tag_string: "aaa", rating: "q", source: "aaa" }, format: :json })

              assert_response(:precondition_failed)
              assert_equal("That image has been deleted and cannot be reuploaded", @response.parsed_body["message"])
              assert_equal("expunged", UploadMediaAsset.last.status)
            end
            perform_enqueued_jobs(only: NotifyExpungedMediaAssetReuploadJob)
          end
        end

        # TODO: reimplement ability to disable notifications
        # should "fail and not create ticket if notify=false" do
        #   DestroyedPost.find_by!(post_id: @post.id).update_column(:notify, false)
        #   assert_difference(%w[Post.count Ticket.count], 0) do
        #     file = fixture_file_upload("test.jpg")
        #     post_auth uploads_path, @user, params: { upload: { file: file, tag_string: "aaa", rating: "q", source: "aaa" } }
        #   end
        # end
      end

      context("access control") do
        setup do
          @file = fixture_file_upload("test.jpg")
          GayFurCity.config.stubs(:disable_age_checks).returns(true)
        end

        asserts do
          access.gte(User::Levels::MEMBER).json.post(uploads_path).params { { upload: { file: @file, tag_string: "aaa", rating: "q", source: "aaa" } } }
        end
      end
    end
  end
end

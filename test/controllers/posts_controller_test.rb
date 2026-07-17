# frozen_string_literal: true

require("test_helper")

class PostsControllerTest < ActionDispatch::IntegrationTest
  context("The posts controller") do
    setup do
      @admin = create(:admin_user)
      @user = create(:user, created_at: 1.month.ago)
      @post = create(:post, tag_string: "aaaa")
    end

    context("index action") do
      should("render") do
        get(posts_path)

        assert_response(:success)
      end

      context("with a search") do
        should("render") do
          get(posts_path, params: { tags: "aaaa" })

          assert_response(:success)
        end
      end

      context("with an md5 param") do
        should("render") do
          get(posts_path, params: { md5: @post.md5 })

          assert_redirected_to(@post)
        end

        should("return error on nonexistent md5") do
          get(posts_path(md5: "foo"))

          assert_response(:not_found)
        end
      end

      context("with a random search") do
        should("render") do
          get(posts_path, params: { tags: "order:random" })

          assert_response(:success)

          get(posts_path, params: { random: "1" })

          assert_response(:success)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(posts_path)
          access.gte(User::Levels::ANONYMOUS).json.get(posts_path)
        end
      end
    end

    context("show_seq action") do
      should("render") do
        posts = create_list(:post, 3)

        get(show_seq_post_path(posts[1].id), params: { seq: "prev" })

        assert_response(:success)

        get(show_seq_post_path(posts[1].id), params: { seq: "next" })

        assert_response(:success)
      end

      context("access control") do
        setup { @posts = create_list(:post, 2) }
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { show_seq_post_path(@posts.first) }.params({ seq: "next" })
          access.gte(User::Levels::ANONYMOUS).json.get { show_seq_post_path(@posts.first) }.params({ seq: "next" })
        end
      end
    end

    context("show action") do
      should("render") do
        get(post_path(@post))

        assert_response(:success)
      end

      should("escape dtext html in post descriptions") do
        @post.update_column(:description, %(<script>alert("xss")</script><img src=x onerror=alert("xss")>))

        get(post_path(@post))

        assert_response(:success)
        assert_includes(@response.body, '&lt;script&gt;alert("xss")&lt;/script&gt;')
        assert_includes(@response.body, '&lt;img src=x onerror=alert("xss")&gt;')
        assert_not_includes(@response.body, "<script>alert(\"xss\")</script>")
        assert_not_includes(@response.body, %{<img src=x onerror=alert("xss")>})
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { post_path(@post) }
          access.gte(User::Levels::ANONYMOUS).json.get { post_path(@post) }
        end
      end
    end

    context("update action") do
      should("work") do
        put_auth(post_path(@post), @user, params: { post: { tag_string: "bbb" } })

        assert_redirected_to(post_path(@post))

        @post.reload

        assert_equal("bbb", @post.tag_string)
      end

      should("ignore restricted params") do
        put_auth(post_path(@post), @user, params: { post: { last_noted_at: 1.minute.ago } })

        assert_nil(@post.reload.last_noted_at)
      end

      should("generate the correct thumbnail") do
        post = create(:webm_upload, uploader: @admin).post

        assert_equal("77ecd5e8577a03090d3864d348d7020b", Digest::MD5.file(post.reload.preview_file_path).hexdigest)
        assert_difference("PostEvent.count", 1) do
          assert_enqueued_jobs(1, only: UploadMediaAssetImageVariantsJob) do
            put_auth(post_path(post), @admin, params: { post: { thumbnail_frame: 5 }, format: :json })
          end
        end
        assert_response(:success)
        perform_enqueued_jobs(only: UploadMediaAssetImageVariantsJob)

        assert_equal("79bb226d5656a47979fdcb94a5feb16a", Digest::MD5.file(post.reload.preview_file_path).hexdigest)
      end

      should("not allow setting thumbnail_frame on posts where framecount=0") do
        @post.media_asset.update_column(:framecount, 0)
        put_auth(post_path(@post), @admin, params: { post: { thumbnail_frame: 1 }, format: :json })

        assert_response(:unprocessable_entity)
        assert_same_elements(["Thumbnail frame cannot be used on posts without a framecount"], @response.parsed_body[:message]&.split("; "))
      end

      should("not allow setting thumbnail_frame greater than framecount") do
        @post.media_asset.update_column(:framecount, 10)
        put_auth(post_path(@post), @admin, params: { post: { thumbnail_frame: 11 }, format: :json })

        assert_response(:unprocessable_entity)
        assert_same_elements(["Thumbnail frame must be between 1 and 10"], @response.parsed_body[:message]&.split("; "))
      end

      should("not allow setting thumbnail_frame further than 10% from the start if framecount is greater than 1000") do
        @post.media_asset.update_column(:framecount, 1500)
        put_auth(post_path(@post), @admin, params: { post: { thumbnail_frame: 200 }, format: :json })

        assert_response(:unprocessable_entity)
        assert_same_elements(["Thumbnail frame must be between 1 and 150", "Thumbnail frame must be in first 10% of video"], @response.parsed_body[:message]&.split("; "))
      end

      context("min_edit_level") do
        setup do
          @post.update_column(:min_edit_level, User::Levels::TRUSTED)
        end

        should("prevent edits when the editors level is lower") do
          put_auth(post_path(@post), @user, params: { post: { tag_string: "test" }, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          put_auth(post_path(@post), @admin, params: { post: { tag_string: "test" }, format: :json })

          assert_response(:success)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { post_path(@post) }.params({ post: { tag_string: "bbb" } }).success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { post_path(@post) }.params({ post: { tag_string: "bbb" } })
        end
      end
    end

    context("revert action") do
      setup do
        @post.update_with(@user, tag_string: "zzz")
      end

      should("work") do
        @version = @post.versions.first

        assert_equal("aaaa", @version.tags)
        put_auth(revert_post_path(@post), @user, params: { version_id: @version.id })

        assert_redirected_to(post_path(@post))
        @post.reload

        assert_equal("aaaa", @post.tag_string)
      end

      should("not allow reverting to a previous version of another post") do
        @post2 = create(:post, tag_string: "herp")

        put_auth(revert_post_path(@post), @user, params: { version_id: @post2.versions.first.id })
        @post.reload

        assert_not_equal(@post.tag_string, @post2.tag_string)
        assert_response(:missing)
      end

      context("min_edit_level") do
        setup do
          @post.update_column(:min_edit_level, User::Levels::TRUSTED)
        end

        should("prevent edits when the editors level is lower") do
          put_auth(revert_post_path(@post), @user, params: { version_id: @post.versions.first.id, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          put_auth(revert_post_path(@post), @admin, params: { version_id: @post.versions.first.id, format: :json })

          assert_response(:success)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { revert_post_path(@post) }.params { { version_id: @post.versions.first.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { revert_post_path(@post) }.params { { version_id: @post.versions.first.id } }
        end
      end
    end

    context("delete action") do
      should("render") do
        get_auth(delete_post_path(@post), @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).get { delete_post_path(@post) }
        end
      end
    end

    context("destroy action") do
      should("work") do
        delete_auth(post_path(@post), @admin, params: { reason: "xxx" })

        assert_predicate(@post.reload, :is_deleted?)
        assert_predicate(@post.uploader.notifications.post_delete, :exists?)
      end

      should("work even if the deleter has flagged the post previously") do
        create(:post_flag, post: @post, reason: "aaa", creator: @user)
        delete_auth(post_path(@post), @admin, params: { reason: "xxx" })

        assert_redirected_to(post_path(@post))
        assert_predicate(@post.reload, :is_deleted?)
      end

      context("access control") do
        setup { create(:post_flag, post: @post) }

        asserts do
          access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).delete { post_path(@post) }.success(:redirect)
          access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.delete { post_path(@post) }
        end
      end
    end

    context("undelete action") do
      should("work") do
        @post.delete!(@user, "test delete")
        assert_difference(-> { PostEvent.count }, 1) do
          put_auth(undelete_post_path(@post), @admin, params: { format: :json })

          assert_response(:success)
        end

        assert_not(@post.reload.is_deleted?)
        assert_predicate(@post.uploader.notifications.post_undelete, :exists?)
      end

      context("access control") do
        setup { @post.delete!(@user, "test delete") }

        asserts do
          access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { undelete_post_path(@post) }.success(:redirect)
          access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { undelete_post_path(@post) }
        end
      end
    end

    context("finish_in_progress action") do
      setup { @post.update_column(:is_in_progress, true) }

      should("let the uploader finish their own post") do
        assert_difference(-> { PostEvent.count }, 1) do
          put_auth(finish_in_progress_post_path(@post), @post.uploader, params: { format: :json })

          assert_response(:success)
        end

        assert_not(@post.reload.is_in_progress?)
        assert_predicate(@post, :is_pending?)
      end

      should("let a janitor force it into the queue") do
        janitor = create(:janitor_user)
        put_auth(finish_in_progress_post_path(@post), janitor, params: { format: :json })

        assert_response(:success)
        assert_not(@post.reload.is_in_progress?)
      end

      should("not let an unrelated member finish it") do
        put_auth(finish_in_progress_post_path(@post), @user, params: { format: :json })

        assert_response(:forbidden)
        assert_predicate(@post.reload, :is_in_progress?)
      end

      context("that has been replaced") do
        setup do
          member = create(:user, created_at: 2.weeks.ago)
          @post = create(:gif_upload, uploader: member, tag_string: create(:artist_tag).name).post
          @post.update_column(:is_in_progress, true)
          @replacement = create(:png_replacement, creator: member, post: @post)
        end

        should("not mention a replacement before one is approved") do
          get(post_path(@post))

          assert_response(:success)
          assert_not_includes(@response.body, "has been replaced from the original upload")
        end

        should("mention that the post has been replaced once a replacement is approved") do
          @replacement.approve!(@replacement.creator, penalize_current_uploader: false)

          get(post_path(@post))

          assert_response(:success)
          assert_includes(@response.body, "has been replaced from the original upload")
        end
      end
    end

    context("expunge action") do
      should("work") do
        put_auth(expunge_post_path(@post), @admin, params: { format: :json })

        assert_response(:success)
        assert_not(::Post.exists?(@post.id))
        assert_equal("expunged", @post.media_asset.reload.status)
      end

      should("work with reason") do
        put_auth(expunge_post_path(@post), @admin, params: { reason: "test", format: :json })

        assert_response(:success)
        assert_not(::Post.exists?(@post.id))
        assert_equal("test", DestroyedPost.last.reason)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).put { expunge_post_path(@post) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { expunge_post_path(@post) }
        end
      end
    end

    context("add_to_pool action") do
      setup do
        @pool = create(:pool, name: "abc")
      end

      should("add a post to a pool") do
        post_auth(add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        @pool.reload

        assert_equal([@post.id], @pool.post_ids)
      end

      should("add a post to a pool once and only once") do
        @pool.add!(@post, @user)
        post_auth(add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        @pool.reload

        assert_equal([@post.id], @pool.post_ids)
      end

      should("update the pool's artists") do
        @post.update_with(@user, tag_string: "artist:foo")
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)

        assert_equal([], @pool.artist_names)
        post_auth(add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)

        assert_same_elements(%w[foo], @pool.reload.artist_names)
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
        end

        should("prevent edits when the editors level is lower") do
          post_auth(add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          post_auth(add_to_pool_post_path(@post), @admin, params: { pool_id: @pool.id, format: :json })

          assert_response(:success)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post { add_to_pool_post_path(@post) }.params { { pool_id: @pool.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post { add_to_pool_post_path(@post) }.params { { pool_id: @pool.id } }
        end
      end
    end

    context("remove_from_pool action") do
      setup do
        @pool = create(:pool, name: "abc")
        @pool.add!(@post, @user)
      end

      should("remove a post from a pool") do
        post_auth(remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        @pool.reload

        assert_equal([], @pool.post_ids)
      end

      should("do nothing if the post is not a member of the pool") do
        @pool.reload
        @pool.remove!(@post, @user)
        post_auth(remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        @pool.reload

        assert_equal([], @pool.post_ids)
      end

      should("update the pool's artists") do
        @post.update_with(@user, tag_string: "artist:foo")
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)

        assert_same_elements(%w[foo], @pool.reload.artist_names)
        post_auth(remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)

        assert_equal([], @pool.reload.artist_names)
      end

      context("min_edit_level") do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
        end

        should("prevent edits when the editors level is lower") do
          post_auth(remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json })

          assert_response(:forbidden)
        end

        should("allow edits when the editors level is higher") do
          post_auth(remove_from_pool_post_path(@post), @admin, params: { pool_id: @pool.id, format: :json })

          assert_response(:success)
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post { remove_from_pool_post_path(@post) }.params { { pool_id: @pool.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post { remove_from_pool_post_path(@post) }.params { { pool_id: @pool.id } }
        end
      end
    end

    context("uploaders action") do
      should("render") do
        get_auth(uploaders_posts_path, @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::JANITOR).get(uploaders_posts_path)
        end
      end
    end

    context("deleted action") do
      should("render") do
        get(deleted_posts_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(deleted_posts_path)
          access.gte(User::Levels::ANONYMOUS).json.get(deleted_posts_path)
        end
      end
    end
  end
end

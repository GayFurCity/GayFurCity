# frozen_string_literal: true

require("test_helper")

module Posts
  class ReplacementsControllerTest < ActionDispatch::IntegrationTest
    context("The post replacements controller") do
      setup do
        @user = create(:janitor_user, created_at: 2.weeks.ago)
        @admin = create(:admin_user)
        @upload = create(:jpg_upload, uploader: @user)
        @post = @upload.post
        @replacement = create(:png_replacement, creator: @user, post: @post)
      end

      context("create action") do
        should("work") do
          disable_image_size_checks!
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:   file,
              reason: "test replacement",
            },
          }

          assert_difference("@post.reload.replacements.size", 1) do
            post_auth(post_replacements_path, @user, params: params)

            assert_response(:success)
            assert_equal(@response.parsed_body["location"], post_path(@post))
          end
        end

        should("work with direct url") do
          disable_image_size_checks!
          file = fixture_file_upload("alpha.png")
          create(:upload_whitelist, pattern: "http://example.com/*")
          CloudflareService.stubs(:ips).returns([])
          stub_request(:get, "http://example.com/alpha.png").to_return(status: 200, body: file.read, headers: { "Content-Type" => "image/png" })
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              direct_url: "http://example.com/alpha.png",
              reason:     "test replacement",
            },
          }

          assert_difference("@post.reload.replacements.size", 1) do
            post_auth(post_replacements_path, @user, params: params)

            assert_response(:success)
            assert_equal(@response.parsed_body["location"], post_path(@post))
          end
        end

        should("automatically approve replacements by approvers") do
          disable_image_size_checks!
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:       file,
              reason:     "test replacement",
              as_pending: false,
            },
          }

          assert_difference("@post.reload.replacements.size", 2) do
            post_auth(post_replacements_path, @user, params: params)

            assert_response(:success)
            assert_equal(post_path(@post), @response.parsed_body["location"])
          end

          assert_equal(%w[approved original], @post.replacements.last(2).pluck(:status))
          assert_not(@user.notifications.replacement_approve.exists?)
        end

        should("not automatically approve replacements by approvers if as_pending=true") do
          disable_image_size_checks!
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:       file,
              reason:     "test replacement",
              as_pending: true,
            },
          }

          assert_difference("@post.replacements.size") do
            post_auth(post_replacements_path, @user, params: params)

            assert_response(:success)
            @post.reload
          end

          assert_equal(@response.parsed_body["location"], post_path(@post))
          assert_equal("pending", @post.replacements.last.status)
        end

        context("with a previously destroyed post") do
          setup do
            @admin = create(:admin_user)
            @replacement.destroy_with(@admin)
            disable_image_size_checks!
            @upload2 = create(:apng_upload, uploader: @user)
            @post2 = @upload2.post
            @post2.expunge!(@admin)
          end

          should("fail and create ticket") do
            previous_md5 = @post.md5
            assert_difference({ "Ticket.count" => 1 }) do
              assert_enqueued_jobs(1, only: NotifyExpungedMediaAssetReuploadJob) do
                file = fixture_file_upload("test.png")
                post_auth(post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { file: file, reason: "test replacement" }, format: :json })

                assert_response(:precondition_failed)
                assert_equal("That image has been deleted and cannot be reuploaded", @response.parsed_body["message"])
                assert_equal("expunged", PostReplacementMediaAsset.last.status)
                assert_equal(previous_md5, @post.reload.md5)
              end
              perform_enqueued_jobs(only: NotifyExpungedMediaAssetReuploadJob)
            end
          end

          should("fail and not create ticket if notify=false") do
            DestroyedPost.find_by!(post_id: @post2.id).update_column(:notify, false)
            assert_difference(%w[Post.count Ticket.count], 0) do
              file = fixture_file_upload("test.png")
              post_auth(post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { replacement_file: file, reason: "test replacement" }, format: :json })
            end
          end
        end

        context("access control") do
          setup do
            disable_image_size_checks!
            GayFurCity.config.stubs(:disable_age_checks).returns(true)
          end

          asserts do
            access.gte(User::Levels::MEMBER).json.post(post_replacements_path).params { { post_replacement: { file: fixture_file_upload("alpha.png"), reason: "test replacement" }, post_id: @post.id } }
          end
        end
      end

      context("reject action") do
        should("reject replacement") do
          janitor = create(:janitor_user)
          put_auth(reject_post_replacement_path(@replacement), janitor)

          assert_redirected_to(post_path(@post))

          @replacement.reload
          @post.reload

          assert_equal("rejected", @replacement.status)
          assert_equal(janitor.id, @replacement.rejector_id)
          assert_not_equal(@replacement.md5, @post.md5)
          assert_predicate(@replacement.creator.notifications.replacement_reject, :exists?)
        end

        should("reject replacement with a reason") do
          put_auth(reject_post_replacement_path(@replacement), @user, params: { post_replacement: { reason: "test" } })

          assert_redirected_to(post_path(@post))
          @replacement.reload
          @post.reload

          assert_equal("rejected", @replacement.status)
          assert_equal(@user.id, @replacement.rejector_id)
          assert_equal("test", @replacement.rejection_reason)
          assert_not_equal(@replacement.md5, @post.md5)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { reject_post_replacement_path(@replacement) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { reject_post_replacement_path(@replacement) }
          end
        end
      end

      context("reject_with_reason action") do
        should("render") do
          get_auth(reject_with_reason_post_replacement_path(@replacement), @user)

          assert_response(:success)
        end

        should("escape prebuilt rejection reasons in text and data attributes") do
          reason_text = %("><script>alert("xss")</script>)
          create(:post_replacement_rejection_reason, creator: @admin, reason: reason_text)

          get_auth(reject_with_reason_post_replacement_path(@replacement), @user)

          assert_response(:success)
          assert_includes(@response.body, CGI.escapeHTML(reason_text))
          assert_not_includes(@response.body, %(data-text="#{reason_text}"))
          assert_not_includes(@response.body, "<script>alert(\"xss\")</script>")
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).get { reject_with_reason_post_replacement_path(@replacement) }
          end
        end
      end

      context("approve action") do
        should("replace post") do
          put_auth(approve_post_replacement_path(@replacement), create(:janitor_user))

          assert_redirected_to(post_path(@post))
          @replacement.reload
          @post.reload

          assert_equal(@replacement.md5, @post.md5)
          assert_equal("approved", @replacement.status)
          assert_predicate(@replacement.creator.notifications.replacement_approve, :exists?)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { approve_post_replacement_path(@replacement) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { approve_post_replacement_path(@replacement) }
          end
        end
      end

      context("promote action") do
        should("create post") do
          post_auth(promote_post_replacement_path(@replacement), create(:janitor_user))
          last_post = Post.last

          assert_redirected_to(post_path(last_post))
          @replacement.reload
          @post.reload

          assert_equal(last_post.md5, @replacement.md5)
          assert_equal("promoted", @replacement.status)
          assert_predicate(@replacement.creator.notifications.replacement_promote, :exists?)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).post { promote_post_replacement_path(@replacement) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.post { promote_post_replacement_path(@replacement) }
          end
        end
      end

      context("toggle action") do
        should("change penalize_uploader flag") do
          put_auth(approve_post_replacement_path(@replacement, penalize_current_uploader: true), @user)
          @replacement.reload

          assert(@replacement.penalize_uploader_on_approve)
          put_auth(toggle_penalize_post_replacement_path(@replacement), @user)

          assert_redirected_to(post_replacement_path(@replacement))
          @replacement.reload

          assert_not(@replacement.penalize_uploader_on_approve)
        end

        context("access control") do
          setup { @replacement.approve!(create(:admin_user), penalize_current_uploader: true) }

          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { toggle_penalize_post_replacement_path(@replacement) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { toggle_penalize_post_replacement_path(@replacement) }
          end
        end
      end

      context("index action") do
        should("render") do
          get(post_replacements_path)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_replacements_path)
            access.gte(User::Levels::ANONYMOUS).json.get(post_replacements_path)
          end
        end

        context("search parameters") do
          subject { post_replacements_path }
          setup do
            Post.connection.execute("TRUNCATE posts CASCADE")
            @creator = create(:user, created_at: 2.weeks.ago)
            @approver = create(:user)
            @rejector = create(:user)
            @uploader_on_approve = create(:user)
            @post = create(:post)
            @admin = create(:admin_user)
            @post_replacement = create(:jpg_replacement, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2", approver: @approver, rejector: @rejector, uploader_on_approve: @uploader_on_approve, status: "approved")
          end

          asserts do
            search(:file_ext, "jpg").records { [@post_replacement] }
            search(:md5, "ecef68c44edb8a0d6a3070b5f8e8ee76").records { [@post_replacement] }
            search(:status, "approved").records { [@post_replacement] }
            search(:post_id).value { @post.id }.records { [@post_replacement] }
            search(:uploader_id_on_approve).value { @uploader_on_approve.id }.records { [@post_replacement] }
            search(:uploader_name_on_approve).value { @uploader_on_approve.name }.records { [@post_replacement] }
            search(:creator_id).value { @creator.id }.records { [@post_replacement] }
            search(:creator_name).value { @creator.name }.records { [@post_replacement] }
            search(:approver_id).value { @approver.id }.records { [@post_replacement] }
            search(:approver_name).value { @approver.name }.records { [@post_replacement] }
            search(:rejector_id).value { @rejector.id }.records { [@post_replacement] }
            search(:rejector_name).value { @rejector.name }.records { [@post_replacement] }
            search(:ip_addr, "127.0.0.2").records { [@post_replacement] }.user { @admin }
            search.shared.records { [@post_replacement] }
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_post_replacement_path, @user, params: { post_id: @post.id })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_post_replacement_path).params { { post_id: @post.id } }
          end
        end
      end

      context("destroy action") do
        should("work") do
          delete_auth(post_replacement_path(@replacement), @admin)

          assert_redirected_to(post_path(@post))
          assert_not(::PostReplacement.exists?(@replacement.id))
          assert_equal("expunged", @replacement.media_asset.reload.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { post_replacement_path(@replacement) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { post_replacement_path(@replacement) }.success(:no_content)
          end
        end
      end
    end
  end
end

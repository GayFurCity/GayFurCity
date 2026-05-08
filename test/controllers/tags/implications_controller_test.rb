# frozen_string_literal: true

require("test_helper")

module Tags
  class TagImplicationsControllerTest < ActionDispatch::IntegrationTest
    context("The tag implications controller") do
      setup do
        @user = create(:user)
        @admin = create(:admin_user)
      end

      context("new action") do
        should("render") do
          get_auth(new_tag_implication_path, @user)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER) { |user| get_auth(new_tag_implication_path, user) }
        end
      end

      context("create action") do
        should("create forum post") do
          assert_difference("ForumTopic.count", 1) do
            post_auth(tag_implications_path, @user, params: { tag_implication: { antecedent_name: "aaa", consequent_name: "bbb", reason: "ccccc" } })
          end
          topic = ForumTopic.last
          post = topic.posts.last

          assert_equal("TagImplication", post.tag_change_request_type)
          assert_equal(TagImplication.last.id, post.tag_change_request_id)
          assert_predicate(post, :allow_voting?)
          assert_redirected_to(forum_topic_path(topic, page: post.forum_topic_page, anchor: "forum_post_#{post.id}"))
        end

        should("work") do
          assert_difference({ "ForumTopic.count" => 1, "TagImplication.count" => 1 }) do
            post_auth(tag_implications_path, @user, params: { tag_implication: { antecedent_name: "foo", consequent_name: "bar", reason: "blah blah" } })
          end
          topic = ForumTopic.last
          post = topic.posts.last
          ti = TagImplication.last

          assert_equal("pending", ti.status)
          assert_equal("TagImplication", post.tag_change_request_type)
          assert_equal(ti.id, post.tag_change_request_id)
          assert_predicate(post, :allow_voting?)
          assert_redirected_to(forum_topic_path(topic, page: post.forum_topic_page, anchor: "forum_post_#{post.id}"))
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(tag_implications_path, user, params: { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } }) }
        end
      end

      context("edit action") do
        setup do
          @tag_implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
        end

        should("render") do
          get_auth(edit_tag_implication_path(@tag_implication), @admin)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(edit_tag_implication_path(@tag_implication), user) }
        end
      end

      context("update action") do
        setup do
          @tag_implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        end

        context("for a pending implication") do
          setup do
            @tag_implication.update_column(:status, "pending")
          end

          should("succeed") do
            put_auth(tag_implication_path(@tag_implication), @admin, params: { tag_implication: { antecedent_name: "xxx" } })
            @tag_implication.reload

            assert_equal("xxx", @tag_implication.antecedent_name)
          end

          should("not allow changing the status") do
            put_auth(tag_implication_path(@tag_implication), @admin, params: { tag_implication: { status: "active" } })
            @tag_implication.reload

            assert_equal("pending", @tag_implication.status)
          end
        end

        context("for an active implication") do
          setup do
            @tag_implication.update_column(:status, "active")
          end

          should("fail") do
            put_auth(tag_implication_path(@tag_implication), @admin, params: { tag_implication: { antecedent_name: "xxx" } })
            @tag_implication.reload

            assert_equal("aaa", @tag_implication.antecedent_name)
          end
        end

        should("restrict access") do
          @tag_implication.update_column(:status, "pending")
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(tag_implication_path(@tag_implication), user, params: { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } }) }
        end
      end

      context("index action") do
        setup do
          @tag_implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        end

        should("list all tag implications") do
          get(tag_implications_path)

          assert_response(:success)
        end

        should("list all tag_implications (with search)") do
          get(tag_implications_path, params: { search: { antecedent_name: "aaa" } })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(tag_implications_path, user) }
        end

        context("search parameters") do
          subject { tag_implications_path }
          setup do
            TagImplication.delete_all
            @creator = create(:user)
            @updater = create(:user)
            @approver = create(:user)
            @admin = create(:admin_user)
            create(:tag, name: "foo", category: TagCategory.copyright)
            create(:tag, name: "bar", category: TagCategory.artist)
            @tag_implication = create(:tag_implication, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", approver: @approver, status: "active", antecedent_name: "foo", consequent_name: "bar")
          end

          assert_search_param(:antecedent_name, "foo", -> { [@tag_implication] })
          assert_search_param(:consequent_name, "bar", -> { [@tag_implication] })
          assert_search_param(:antecedent_tag_category, TagCategory.copyright, -> { [@tag_implication] })
          assert_search_param(:consequent_tag_category, TagCategory.artist, -> { [@tag_implication] })
          assert_search_param(:name_matches, "foo", -> { [@tag_implication] })
          assert_search_param(:name_matches, "bar", -> { [@tag_implication] })
          assert_search_param(:status, "active", -> { [@tag_implication] })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@tag_implication] })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@tag_implication] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@tag_implication] }, -> { @admin })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@tag_implication] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@tag_implication] })
          assert_search_param(:updater_ip_addr, "127.0.0.3", -> { [@tag_implication] }, -> { @admin })
          assert_search_param(:approver_id, -> { @approver.id }, -> { [@tag_implication] })
          assert_search_param(:approver_name, -> { @approver.name }, -> { [@tag_implication] })
          assert_shared_search_params(-> { [@tag_implication] })
        end
      end

      context("approve action") do
        setup do
          @tag_implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
        end

        should("approve the implication") do
          put_auth(approve_tag_implication_path(@tag_implication), @admin, params: { format: :json })

          assert_response(:success)
          perform_enqueued_jobs(only: TagImplicationJob)
          @tag_implication.reload

          assert_equal("active", @tag_implication.status)
        end

        should("not approve the implication if its estimated count is greater than allowed") do
          Config.stubs(:get_user).with(:tag_change_request_update_limit, @admin).returns(1)
          create_list(:post, 2, tag_string: "aaa")
          put_auth(approve_tag_implication_path(@tag_implication), @admin, params: { format: :json })

          assert_response(:forbidden)
          assert_equal("pending", @tag_implication.status)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(approve_tag_implication_path(create(:tag_implication, antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), status: "pending", creator: @admin)), user) }
        end
      end

      context("destroy action") do
        setup do
          @tag_implication = create(:tag_implication, creator: @admin)
        end

        should("mark the implication as deleted") do
          assert_difference("TagImplication.count", 0) do
            delete_auth(tag_implication_path(@tag_implication), @admin)

            assert_equal("deleted", @tag_implication.reload.status)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(tag_implication_path(create(:tag_implication, antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), status: "pending", creator: @admin)), user) }
        end
      end
    end
  end
end

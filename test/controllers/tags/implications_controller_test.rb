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

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_tag_implication_path)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).post(tag_implications_path).params { { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), reason: "ccccc" } } }.success(:redirect)
            access.gte(User::Levels::MEMBER).json.post(tag_implications_path).params { { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), reason: "ccccc" } } }
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_tag_implication_path(@tag_implication) }
          end
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

        context("access control") do
          setup { @tag_implication.update_column(:status, "pending") }

          asserts do
            access.gte(User::Levels::ADMIN).put { tag_implication_path(@tag_implication) }.params { { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } } }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { tag_implication_path(@tag_implication) }.params { { tag_implication: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } } }
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(tag_implications_path)
            access.gte(User::Levels::ANONYMOUS).json.get(tag_implications_path)
          end
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

          asserts do
            search(:antecedent_name, "foo").records { [@tag_implication] }
            search(:consequent_name, "bar").records { [@tag_implication] }
            search(:antecedent_tag_category, TagCategory.copyright).records { [@tag_implication] }
            search(:consequent_tag_category, TagCategory.artist).records { [@tag_implication] }
            search(:name_matches, "foo").records { [@tag_implication] }
            search(:name_matches, "bar").records { [@tag_implication] }
            search(:status, "active").records { [@tag_implication] }
            search(:creator_id).value { @creator.id }.records { [@tag_implication] }
            search(:creator_name).value { @creator.name }.records { [@tag_implication] }
            search(:ip_addr, "127.0.0.2").records { [@tag_implication] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@tag_implication] }
            search(:updater_name).value { @updater.name }.records { [@tag_implication] }
            search(:updater_ip_addr, "127.0.0.3").records { [@tag_implication] }.user { @admin }
            search(:approver_id).value { @approver.id }.records { [@tag_implication] }
            search(:approver_name).value { @approver.name }.records { [@tag_implication] }
            search.shared.records { [@tag_implication] }
          end
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
          reset_post_index
          stub_dynamic_config(:tag_change_request_update_limit, 1)
          create_list(:post, 2, tag_string: "aaa")
          put_auth(approve_tag_implication_path(@tag_implication), @admin, params: { format: :json })

          assert_response(:forbidden)
          assert_equal("pending", @tag_implication.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { approve_tag_implication_path(@tag_implication) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { approve_tag_implication_path(@tag_implication) }
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { tag_implication_path(@tag_implication) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { tag_implication_path(@tag_implication) }.success(:no_content)
          end
        end
      end
    end
  end
end

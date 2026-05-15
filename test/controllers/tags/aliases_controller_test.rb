# frozen_string_literal: true

require("test_helper")

module Tags
  class AliasesControllerTest < ActionDispatch::IntegrationTest
    context("The tag aliases controller") do
      setup do
        @user = create(:user)
        @admin = create(:admin_user)
      end

      context("new action") do
        should("render") do
          get_auth(new_tag_alias_path, @user)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_tag_alias_path)
          end
        end
      end

      context("create action") do
        should("work") do
          assert_difference({ "ForumTopic.count" => 1, "TagAlias.count" => 1 }) do
            post_auth(tag_aliases_path, @user, params: { tag_alias: { antecedent_name: "aaa", consequent_name: "bbb", reason: "ccccc" } })
          end
          topic = ForumTopic.last
          post = topic.posts.last
          ta = TagAlias.last

          assert_equal("pending", ta.status)
          assert_equal("TagAlias", post.tag_change_request_type)
          assert_equal(ta.id, post.tag_change_request_id)
          assert_predicate(post, :allow_voting?)
          assert_redirected_to(forum_topic_path(topic, page: post.forum_topic_page, anchor: "forum_post_#{post.id}"))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).post(tag_aliases_path).params { { tag_alias: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), reason: "ccccc" } } }.success(:redirect)
            access.gte(User::Levels::MEMBER).json.post(tag_aliases_path).params { { tag_alias: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6), reason: "ccccc" } } }
          end
        end
      end

      context("edit action") do
        setup do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
        end

        should("render") do
          get_auth(edit_tag_alias_path(@tag_alias), @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_tag_alias_path(@tag_alias) }
          end
        end
      end

      context("update action") do
        setup do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        end

        context("for a pending alias") do
          setup do
            @tag_alias.update_column(:status, "pending")
          end

          should("succeed") do
            put_auth(tag_alias_path(@tag_alias), @admin, params: { tag_alias: { antecedent_name: "xxx" } })
            @tag_alias.reload

            assert_equal("xxx", @tag_alias.antecedent_name)
          end

          should("not allow changing the status") do
            put_auth(tag_alias_path(@tag_alias), @admin, params: { tag_alias: { status: "active" } })
            @tag_alias.reload

            assert_equal("pending", @tag_alias.status)
          end
        end

        context("for an active alias") do
          setup do
            @tag_alias.update_column(:status, "active")
          end

          should("fail") do
            put_auth(tag_alias_path(@tag_alias), @admin, params: { tag_alias: { antecedent_name: "xxx" } })
            @tag_alias.reload

            assert_equal("aaa", @tag_alias.antecedent_name)
          end
        end

        context("access control") do
          setup { @tag_alias.update_column(:status, "pending") }
          asserts do
            access.gte(User::Levels::ADMIN).put { tag_alias_path(@tag_alias) }.params { { tag_alias: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } } }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { tag_alias_path(@tag_alias) }.params { { tag_alias: { antecedent_name: SecureRandom.hex(6), consequent_name: SecureRandom.hex(6) } } }
          end
        end
      end

      context("index action") do
        setup do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        end

        should("list all tag alias") do
          get_auth(tag_aliases_path, @admin)

          assert_response(:success)
        end

        should("list all tag_alias (with search)") do
          get_auth(tag_aliases_path, @admin, params: { search: { antecedent_name: "aaa" } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(tag_aliases_path)
            access.gte(User::Levels::ANONYMOUS).json.get(tag_aliases_path)
          end
        end

        context("search parameters") do
          subject { tag_aliases_path }
          setup do
            TagAlias.delete_all
            @creator = create(:user)
            @updater = create(:user)
            @approver = create(:user)
            @admin = create(:admin_user)
            create(:tag, name: "foo", category: TagCategory.copyright)
            create(:tag, name: "bar", category: TagCategory.artist)
            @tag_alias = create(:tag_alias, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", approver: @approver, status: "active", antecedent_name: "foo", consequent_name: "bar")
          end

          asserts do
            search(:antecedent_name, "foo").records { [@tag_alias] }
            search(:consequent_name, "bar").records { [@tag_alias] }
            search(:antecedent_tag_category, TagCategory.copyright).records { [@tag_alias] }
            search(:consequent_tag_category, TagCategory.artist).records { [@tag_alias] }
            search(:name_matches, "foo").records { [@tag_alias] }
            search(:name_matches, "bar").records { [@tag_alias] }
            search(:status, "active").records { [@tag_alias] }
            search(:creator_id).value { @creator.id }.records { [@tag_alias] }
            search(:creator_name).value { @creator.name }.records { [@tag_alias] }
            search(:ip_addr, "127.0.0.2").records { [@tag_alias] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@tag_alias] }
            search(:updater_name).value { @updater.name }.records { [@tag_alias] }
            search(:updater_ip_addr, "127.0.0.3").records { [@tag_alias] }.user { @admin }
            search(:approver_id).value { @approver.id }.records { [@tag_alias] }
            search(:approver_name).value { @approver.name }.records { [@tag_alias] }
            search.shared.records { [@tag_alias] }
          end
        end
      end

      context("approve action") do
        setup do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
        end

        should("approve the alias") do
          put_auth(approve_tag_alias_path(@tag_alias), @admin, params: { format: :json })

          assert_response(:success)
          perform_enqueued_jobs(only: TagAliasJob)
          @tag_alias.reload

          assert_equal("active", @tag_alias.status)
        end

        should("not approve the alias if its estimated count is greater than allowed") do
          Config.stubs(:get_user).with(:tag_change_request_update_limit, @admin).returns(1)
          create_list(:post, 2, tag_string: "aaa")
          put_auth(approve_tag_alias_path(@tag_alias), @admin, params: { format: :json })

          assert_response(:forbidden)
          assert_equal("pending", @tag_alias.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { approve_tag_alias_path(@tag_alias) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { approve_tag_alias_path(@tag_alias) }
          end
        end
      end

      context("destroy action") do
        setup do
          @tag_alias = create(:tag_alias, creator: @admin)
        end

        should("mark the alias as deleted") do
          assert_difference("TagAlias.count", 0) do
            delete_auth(tag_alias_path(@tag_alias), @admin)

            assert_equal("deleted", @tag_alias.reload.status)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { tag_alias_path(@tag_alias) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { tag_alias_path(@tag_alias) }.success(:no_content)
          end
        end
      end
    end
  end
end

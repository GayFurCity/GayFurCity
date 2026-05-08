# frozen_string_literal: true

require("test_helper")

class UserAdminEditTest < ActiveSupport::TestCase
  context("A user admin edit") do
    setup do
      @user = create(:trusted_user, email_verified: false)
      @admin = create(:admin_user)
      @owner = create(:owner_user)
    end

    context("level") do
      should("allow owner to promote to admin") do
        assert_difference("ModAction.count", 1) do
          edit = UserAdminEdit.new(@user, @owner, "127.0.0.1", { level: User::Levels::ADMIN })
          edit.apply

          assert_predicate(edit, :valid?)
        end
        assert_equal(User::Levels::ADMIN, @user.reload.level)
        assert_equal(%w[user_level_change], ModAction.last(1).pluck(:action))
      end

      should("not allow admin to promote to admin") do
        assert_no_difference("ModAction.count") do
          edit = UserAdminEdit.new(@user, @admin, "127.0.0.1", { level: User::Levels::ADMIN })
          edit.apply

          assert_predicate(edit, :invalid?)
        end
        assert_equal(User::Levels::TRUSTED, @user.reload.level)
      end

      should("allow admin to promote to moderator") do
        assert_difference("ModAction.count", 1) do
          edit = UserAdminEdit.new(@user, @admin, "127.0.0.1", { level: User::Levels::MODERATOR })
          edit.apply

          assert_predicate(edit, :valid?)
        end
        assert_equal(User::Levels::MODERATOR, @user.reload.level)
        assert_equal(%w[user_level_change], ModAction.last(1).pluck(:action))
      end
    end

    context("email") do
      should("allow owner") do
        UserAdminEdit.new(@user, @owner, "127.0.0.1", { email: "test@gayfur.city" }).apply!

        assert_equal("test@gayfur.city", @user.reload.email)
      end

      should("not allow admin") do
        old_email = @user.email
        UserAdminEdit.new(@user, @admin, "127.0.0.1", { email: "test@gayfur.city" }).apply!

        assert_equal(old_email, @user.reload.email)
      end
    end

    context("name") do
      should("work") do
        assert_difference(%w[ModAction.count UserNameChangeRequest.count], 1) do
          edit = UserAdminEdit.new(@user, @admin, "127.0.0.1", { name: "xaxaxa" })
          edit.apply

          assert_predicate(edit, :valid?)
        end
        assert_equal("xaxaxa", @user.reload.name)
        assert_equal(%w[user_name_change], ModAction.last(1).pluck(:action))
      end
    end

    context("title") do
      should("allow owner") do
        UserAdminEdit.new(@user, @owner, "127.0.0.1", { title: "Test" }).apply!

        assert_equal("Test", @user.reload.title)
      end

      should("not allow admin") do
        UserAdminEdit.new(@user, @admin, "127.0.0.1", { title: "Test" }).apply!

        assert_nil(@user.reload.title)
      end
    end

    context("profile_about") do
      should("work") do
        UserAdminEdit.new(@user, @admin, "127.0.0.1", { profile_about: "test" }).apply!

        assert_equal("test", @user.reload.profile_about)
      end
    end

    context("profile_artinfo") do
      should("work") do
        UserAdminEdit.new(@user, @admin, "127.0.0.1", { profile_artinfo: "test" }).apply!

        assert_equal("test", @user.reload.profile_artinfo)
      end
    end

    context("base_upload_limit") do
      should("work") do
        UserAdminEdit.new(@user, @admin, "127.0.0.1", { base_upload_limit: 20 }).apply!

        assert_equal(20, @user.reload.base_upload_limit)
      end
    end

    context("preferences") do
      %i[email_verified can_manage_aibur].each do |pref|
        context(pref) do
          should("allow owner") do
            UserAdminEdit.new(@user, @owner, "127.0.0.1", pref => true).apply!

            assert(@user.reload.send(pref))
          end

          should("not allow admin") do
            UserAdminEdit.new(@user, @admin, "127.0.0.1", pref => true).apply!

            assert_not(@user.reload.send(pref))
          end
        end
      end

      %i[enable_privacy_mode unrestricted_uploads can_approve_posts no_flagging no_replacements no_aibur_voting force_name_change].each do |pref|
        context(pref) do
          should("work") do
            UserAdminEdit.new(@user, @admin, "127.0.0.1", pref => true).apply!

            assert(@user.reload.send(pref))
          end
        end
      end
    end
  end
end

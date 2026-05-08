# frozen_string_literal: true

require("test_helper")

class AvoidPostingsControllerTest < ActionDispatch::IntegrationTest
  context("The avoid postings controller") do
    setup do
      @user = create(:user)
      @owner_user = create(:owner_user)

      @avoid_posting = create(:avoid_posting)
      @artist = @avoid_posting.artist
    end

    context("index action") do
      should("render") do
        get_auth(avoid_postings_path, @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(avoid_postings_path, user) }
      end

      context("search parameters") do
        subject { avoid_postings_path }
        setup do
          AvoidPostingVersion.delete_all
          AvoidPosting.delete_all
          @user = create(:user)
          @updater = create(:user)
          @artist = create(:artist, name: "foo", creator: @user)
          @janitor = create(:janitor_user)
          @admin = create(:admin_user)
          @avoid_posting = create(:avoid_posting, is_active: true, details: "bar", staff_notes: "baz", artist: @artist, creator: @user, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3")
        end

        assert_search_param(:is_active, "true", -> { [@avoid_posting] })
        assert_search_param(:artist_id, -> { @artist.id }, -> { [@avoid_posting] })
        assert_search_param(:artist_name, "foo", -> { [@avoid_posting] })
        assert_search_param(:details, "bar", -> { [@avoid_posting] })
        assert_search_param(:staff_notes, "baz", -> { [@avoid_posting] }, -> { @janitor })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@avoid_posting] }, -> { @admin })
        assert_search_param(:updater_ip_addr, "127.0.0.3", -> { [@avoid_posting] }, -> { @admin })
        assert_search_param(:creator_id, -> { @user.id }, -> { [@avoid_posting] })
        assert_search_param(:creator_name, -> { @user.name }, -> { [@avoid_posting] })
        assert_search_param(:updater_id, -> { @updater.id }, -> { [@avoid_posting] })
        assert_search_param(:updater_name, -> { @updater.name }, -> { [@avoid_posting] })
        assert_shared_search_params(-> { [@avoid_posting] })
      end
    end

    context("show action") do
      should("render") do
        get_auth(avoid_posting_path(@avoid_posting), @user)

        assert_response(:success)
      end

      should("render (by name)") do
        get_auth(avoid_posting_path(id: @avoid_posting.artist_name), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(avoid_posting_path(@avoid_posting), user) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_avoid_posting_path(@avoid_posting), @owner_user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER) { |user| get_auth(edit_avoid_posting_path(@avoid_posting), user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_avoid_posting_path, @owner_user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER) { |user| get_auth(new_avoid_posting_path, user) }
      end
    end

    context("create action") do
      should("work and create artist") do
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count Artist.count], 1) do
          post_auth(avoid_postings_path, @owner_user, params: { avoid_posting: { artist_attributes: { name: "another_artist" } } })
        end

        artist = Artist.find_by(name: "another_artist")

        assert_not_nil(artist)
        avoid_posting = AvoidPosting.find_by(artist: artist)

        assert_not_nil(avoid_posting)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should("work with existing artist") do
        @artist = create(:artist)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth(avoid_postings_path, @owner_user, params: { avoid_posting: { artist_attributes: { name: @artist.name } } })
        end

        avoid_posting = AvoidPosting.find_by(artist: @artist)

        assert_not_nil(avoid_posting)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should("merge other_names if already set") do
        @artist = create(:artist, other_names: %w[test1 test2])
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth(avoid_postings_path, @owner_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, other_names_string: "test2 test3" } } })
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)

        assert_not_nil(avoid_posting)
        assert_equal(%w[test1 test2 test3], @artist.other_names)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should("reject linked_user_id if already set") do
        @artist = create(:artist, linked_user: @owner_user)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth(avoid_postings_path, @owner_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, linked_user_id: create(:user).id } } })
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)

        assert_not_nil(avoid_posting)
        assert_equal(@owner_user, @artist.linked_user)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should("not override existing artist properties with empty fields") do
        @artist = create(:artist, other_names: %w[test1 test2], linked_user: @owner_user)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth(avoid_postings_path, @owner_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, other_names: [], other_names_string: "", linked_user_id: "" } } })

          assert_response(:redirect)
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)

        assert_not_nil(avoid_posting)
        assert_equal(%w[test1 test2], @artist.other_names)
        assert_equal(@owner_user, @artist.linked_user)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER, success_response: :redirect) { |user| post_auth(avoid_postings_path, user, params: { avoid_posting: { artist_attributes: { name: SecureRandom.hex(6) } } }) }
      end
    end

    context("update action") do
      should("work") do
        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth(avoid_posting_path(@avoid_posting), @owner_user, params: { avoid_posting: { details: "test" } })
        end

        assert_redirected_to(avoid_posting_path(@avoid_posting))
        assert_equal("avoid_posting_update", ModAction.last.action)
        assert_equal("test", @avoid_posting.reload.details)
      end

      should("work with nested attributes") do
        assert_difference({ "ModAction.count" => 1, "AvoidPostingVersion.count" => 0 }) do
          put_auth(avoid_posting_path(@avoid_posting), @owner_user, params: { avoid_posting: { artist_attributes: { id: @avoid_posting.artist.id, name: "foobar" } } })
        end

        assert_redirected_to(avoid_posting_path(@avoid_posting))
        assert_equal("artist_rename", ModAction.last.action)
        assert_equal("foobar", @avoid_posting.artist.reload.name)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER, success_response: :redirect) { |user| put_auth(avoid_posting_path(@avoid_posting), user, params: { avoid_posting: { details: "test" } }) }
      end
    end

    context("delete action") do
      should("work") do
        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth(delete_avoid_posting_path(@avoid_posting), @owner_user)
        end

        assert_not(@avoid_posting.reload.is_active?)
        assert_equal("avoid_posting_delete", ModAction.last.action)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER, success_response: :redirect) { |user| put_auth(delete_avoid_posting_path(@avoid_posting), user) }
      end
    end

    context("undelete action") do
      should("work") do
        @avoid_posting.update_column(:is_active, false)

        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth(undelete_avoid_posting_path(@avoid_posting), @owner_user)
        end

        assert_predicate(@avoid_posting.reload, :is_active?)
        assert_equal("avoid_posting_undelete", ModAction.last.action)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER, success_response: :redirect) { |user| put_auth(undelete_avoid_posting_path(@avoid_posting), user) }
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference({ "ModAction.count" => 1, "AvoidPosting.count" => -1 }) do
          delete_auth(avoid_posting_path(@avoid_posting), @owner_user)
        end

        assert_nil(AvoidPosting.find_by(id: @avoid_posting.id))
        assert_equal("avoid_posting_destroy", ModAction.last.action)
      end

      should("restrict access") do
        assert_access(User::Levels::OWNER, success_response: :redirect) { |user| delete_auth(avoid_posting_path(create(:avoid_posting)), user) }
      end
    end
  end
end

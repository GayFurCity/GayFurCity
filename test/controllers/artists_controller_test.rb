# frozen_string_literal: true

require("test_helper")

class ArtistsControllerTest < ActionDispatch::IntegrationTest
  context("The artists controller") do
    setup do
      @admin = create(:admin_user)
      @user = create(:janitor_user)
      @artist = create(:artist, notes: "message")
      @masao = create(:artist, name: "masao", url_string: "http://www.pixiv.net/member.php?id=32777")
      @artgerm = create(:artist, name: "artgerm", url_string: "http://artgerm.deviantart.com/")
    end

    context("new action") do
      should("render") do
        get_auth(new_artist_path, @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(new_artist_path, user) }
      end
    end

    context("show_or_new action") do
      should("get the show_or_new page for an existing artist") do
        get_auth(show_or_new_artists_path(name: "masao"), @user)

        assert_redirected_to(@masao)
      end

      should("get the show_or_new page for a nonexisting artist") do
        get_auth(show_or_new_artists_path(name: "nobody"), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(show_or_new_artists_path, user) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_artist_path(@artist), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(edit_artist_path(@artist), user) }
      end
    end

    context("update action") do
      should("work") do
        put_auth(artist_path(@artist), @user, params: { artist: { notes: "xyz" } })
        @artist.reload

        assert_equal("xyz", @artist.notes)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(artist_path(@artist), user, params: { artist: { notes: "xyz" } }) }
      end
    end

    context("show action") do
      should("render") do
        get(artist_path(@artist))

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(artist_path(@artist), user) }
      end
    end

    context("index action") do
      should("render") do
        get(artists_path)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(artists_path, user) }
      end

      context("search parameters") do
        subject { artists_path }
        setup do
          ArtistUrl.delete_all
          ArtistVersion.delete_all
          Artist.delete_all
          @user = create(:user)
          @linked = create(:user)
          @admin = create(:admin_user)
          @artist = create(:artist, name: "foo", other_names: "bar baz", url_string: "https://google.com", linked_user: @linked, creator: @user, creator_ip_addr: "127.0.0.2")
        end

        assert_search_param(:name, "foo", -> { [@artist] }, include: %i[urls])
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@artist] }, -> { @admin }, include: %i[urls])
        assert_search_param(:any_other_name_matches, "bar", -> { [@artist] }, include: %i[urls])
        assert_search_param(:any_other_name_like, "baz", -> { [@artist] }, include: %i[urls])
        assert_search_param(:any_name_matches, "foo", -> { [@artist] }, include: %i[urls])
        assert_search_param(:any_name_or_url_matches, "https://google.com", -> { [@artist] }, include: %i[urls])
        assert_search_param(:url_matches, "google.com", -> { [@artist] }, include: %i[urls])
        assert_search_param(:is_linked, "true", -> { [@artist] }, include: %i[urls])
        assert_search_param(:has_tag, "true", -> { [create(:artist, name: create(:tag, post_count: 10).name)] }, include: %i[urls])
        assert_search_param(:creator_id, -> { @user.id }, -> { [@artist] }, include: %i[urls])
        assert_search_param(:creator_name, -> { @user.name }, -> { [@artist] }, include: %i[urls])
        assert_search_param(:linked_user_id, -> { @linked.id }, -> { [@artist] }, include: %i[urls])
        assert_search_param(:linked_user_name, -> { @linked.name }, -> { [@artist] }, include: %i[urls])
        assert_shared_search_params(-> { [@artist] }, nil, %w[id created_at], include: %i[urls])
      end
    end

    context("create action") do
      should("work") do
        attributes = attributes_for(:artist)
        assert_difference("Artist.count", 1) do
          attributes.delete(:is_active)
          post_auth(artists_path, @user, params: { artist: attributes })
        end

        artist = Artist.find_by(name: attributes[:name])

        assert_not_nil(artist)
        assert_redirected_to(artist_path(artist.id))
      end

      should("work (with url string)") do
        attributes = attributes_for(:artist)
        attributes[:url_string] ||= GayFurCity.config.hostname
        assert_difference(%w[Artist.count ArtistUrl.count], 1) do
          attributes.delete(:is_active)
          post_auth(artists_path, @user, params: { artist: attributes })
        end

        artist = Artist.find_by(name: attributes[:name])

        assert_not_nil(artist)
        assert_redirected_to(artist_path(artist.id))
      end

      should("return expected errors") do
        post_auth(artists_path, @user, params: { artist: { name: @artist.name }, format: "json" })

        assert_error_response("name", "has already been taken")

        post_auth(artists_path, @user, params: { artist: { name: "" }, format: "json" })

        assert_error_response("name", "'' cannot be blank")

        post_auth(artists_path, @user, params: { artist: { name: "a" * 101 }, format: "json" })

        assert_error_response("name", "is too long (maximum is 100 characters)")
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(artists_path, user, params: { artist: { name: SecureRandom.hex(6) } }) }
      end
    end

    context("with an artist that has notes") do
      setup do
        @artist = create(:artist, name: "aaa", notes: "testing", url_string: "http://example.com")
        @wiki_page = @artist.wiki_page
        @another_user = create(:user)
      end

      should("update an artist") do
        old_timestamp = @wiki_page.updated_at
        travel_to(1.minute.from_now) do
          put_auth(artist_path(@artist.id), @user, params: { artist: { notes: "rex", url_string: "http://example.com\nhttp://monet.com" } })
        end
        @artist.reload
        @wiki_page = @artist.wiki_page

        assert_equal("rex", @artist.notes)
        assert_not_equal(old_timestamp, @wiki_page.updated_at)
        assert_redirected_to(artist_path(@artist.id))
      end

      should("not touch the updater_id and updated_at fields when nothing is changed") do
        old_timestamp = @wiki_page.updated_at
        old_updater_id = @wiki_page.updater_id

        travel_to(1.minute.from_now) do
          @artist.update_with(@another_user, notes: "testing")
        end

        @artist.reload
        @wiki_page = @artist.wiki_page

        assert_in_delta(old_timestamp.to_i, @wiki_page.updated_at.to_i, 1)
        assert_equal(old_updater_id, @wiki_page.updater_id)
      end

      context("when renaming an artist") do
        should("automatically rename the artist's wiki page") do
          assert_difference("WikiPage.count", 0) do
            put_auth(artist_path(@artist), @user, params: { artist: { name: "bbb", notes: "more testing" } })
          end
          @wiki_page.reload

          assert_equal("bbb", @wiki_page.title)
          assert_equal("more testing", @wiki_page.body)
        end
      end

      should("propagate is_locked") do
        put_auth(artist_path(@artist), @user, params: { artist: { is_locked: true } })
        @artist.reload
        @wiki_page.reload

        assert_predicate(@artist, :is_locked?)
        assert_equal(User::Levels.min_staff_level, @wiki_page.protection_level)
      end

      should("not lower the protection level") do
        @wiki_page.update_column(:protection_level, User::Levels::ADMIN)
        put_auth(artist_path(@artist), @user, params: { artist: { is_locked: true } })
        @artist.reload
        @wiki_page.reload

        assert_predicate(@artist, :is_locked?)
        assert_equal(User::Levels::ADMIN, @wiki_page.protection_level)
      end

      should("enforce protections") do
        @wiki_page.update_column(:protection_level, User::Levels::ADMIN)
        put_auth(artist_path(@artist), @user, params: { artist: { notes: "xxx" } })
        @artist.reload

        assert_equal("testing", @artist.notes)
      end
    end

    context("destroy action") do
      should("delete an artist") do
        @admin = create(:admin_user)
        delete_auth(artist_path(@artist), @admin)

        assert_redirected_to(artists_path)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(artist_path(create(:artist)), user) }
      end
    end

    context("revert action") do
      should("work") do
        @artist.update_with(@user, name: "xyz")
        @artist.update_with(@user, name: "abc")
        put_auth(revert_artist_path(@artist), @user, params: { version_id: @artist.versions.first.id })
      end

      should("not allow reverting to a previous version of another artist") do
        @artist2 = create(:artist)
        put_auth(artist_path(@artist), @user, params: { version_id: @artist2.versions.first.id })
        @artist.reload

        assert_not_equal(@artist.name, @artist2.name)
        assert_redirected_to(artist_path(@artist.id))
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(revert_artist_path(@artist), user, params: { version_id: @artist.versions.first.id }) }
      end
    end

    context("with a dnp entry") do
      setup do
        @owner_user = create(:owner_user)
        @avoid_posting = create(:avoid_posting, artist: @artist)
      end

      should("not allow destroying") do
        assert_no_difference("Artist.count") do
          delete_auth(artist_path(@artist), @owner_user)
        end
      end

      # technical restriction
      should("not allow destroying even if the dnp is inactive") do
        @avoid_posting.update_columns(is_active: false)
        assert_no_difference("Artist.count") do
          delete_auth(artist_path(@artist), @owner_user)
        end
      end

      should("not allow editing protected properties") do
        @janitor = create(:janitor_user)
        name = @artist.name
        other_names = @artist.other_names
        assert_no_difference("ModAction.count") do
          put_auth(artist_path(@artist), @janitor, params: { artist: { name: "another_name", other_names: "some other names" } })
        end

        @artist.reload

        assert_equal(name, @artist.name)
        assert_equal(other_names, @artist.other_names)
        assert_equal(name, @artist.wiki_page.reload.title)
        assert_equal(name, @avoid_posting.reload.artist_name)
      end
    end
  end
end

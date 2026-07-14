# frozen_string_literal: true

module PostSets
  class Favorites < PostSets::Base
    attr_reader(:user, :page, :limit)

    def initialize(user, page, limit:, current_user:)
      super(current_user)
      @user = user
      @page = page
      @limit = limit
    end

    def public_tag_string
      "fav:#{user.name}"
    end

    def current_page
      [page.to_i, 1].max
    end

    def favorites
      @post_count ||= ::Post.tag_match("fav:#{user.name} status:any", current_user).count_only
      @favorites ||= ::Favorite.for_user(@user.id).includes(:post).order(created_at: :desc).paginate_posts(page, total_count: @post_count, limit: limit, user: current_user)
    end

    def posts
      # pagination_mode/current_page must come from favorites (the actual paginated relation) rather
      # than being hardcoded/recomputed here - `page` can be a plain number, or a "b<id>"/"a<id>"
      # sequential cursor, and favorites.pagination_mode/current_page already reflect whichever of
      # those it actually was.
      #
      # For sequential modes, favorites (already-truncated by ActiveRecordExtension#records) doesn't
      # carry the "is there another page" lookahead row PaginatedArray needs to compute is_first_page?/
      # is_last_page? correctly - paginator_raw_records is the untruncated fetch that still has it.
      records = favorites.pagination_mode == :numbered ? favorites : favorites.paginator_raw_records
      new_opts = { pagination_mode: favorites.pagination_mode, records_per_page: favorites.records_per_page, total_count: @post_count, current_page: favorites.current_page }
      GayFurCity::Paginator::PaginatedArray.new(records.map(&:post), new_opts)
    end

    def api_posts
      favorites = self.favorites
      fill_children(favorites)
      favorites
    end

    def fill_children(favorites)
      super(favorites.map(&:post))
    end

    def tag_array
      []
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end
  end
end

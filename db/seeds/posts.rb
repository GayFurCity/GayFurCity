# frozen_string_literal: true

module Seeds
  class Posts
    MAX_PER_PAGE = 500
    Pool = Struct.new(:id, :name, :created_at, :updated_at, :creator_id, :description, :is_active, :category, :post_ids, :creator_name, :post_count, :artist_names, :cover_post_id)

    def self.run!(user = User.system, limit = ENV.fetch("SEED_POST_COUNT", 100).to_i)
      new(user).run!(limit)
    end

    attr_reader(:user)

    def initialize(user = User.system)
      @user = user.resolvable
    end

    def run!(limit)
      return if limit == 0
      ENV["SEEDING"] = "1"
      @limit = limit
      Seeds.read_resources do |r|
        @tags = r["post_ids"].blank? ? r["tags"] : %W[id:#{r['post_ids'].join(',')}]
      end
      @before = ::Post.count
      @total = 0 # posts created, excluding parent/child chains
      get_posts do |posts, page|
        now = ::Post.count
        posts.each_with_index do |data, i|
          post = process_post(data, text: "[#{(now - @before) + i + 1}/#{@limit}]")
          @total += 1 unless post.nil?
        end
        Seeds.log("Get #{posts.count} On Page ##{page} - #{::Post.count - @before}/#{@limit}")
      end
      @after = ::Post.count
      Seeds.log("Created #{@after - @before} posts from #{@total} (#{@limit}) requested posts.")
      ENV["SEEDING"] = "0"
    end

    def process_post(data, text: nil, relationships: fetch_related_posts?)
      data = data.dup
      # return Struct.new(:id, :parent_id).new(id: 0, parent_id: nil)
      data["sources"] << "#{Seeds.base_url}/posts/#{data['id']}"
      data["tags"].each do |category, tags|
        next unless TagCategory.category_names.include?(category) # If we don't support the category, let the tags be created with the post
        Tag.find_or_create_by_name_list(tags.map { |tag| "#{category}:#{tag}" }, user: user)
      end

      process_related_posts(data, text: text) if relationships
      process_post_pools(data, text: text)
      create_post(data, text: text)
    end

    def create_post(data, text: nil)
      existing = Post.joins(:media_asset).find_by("upload_media_assets.md5": data["file"]["md5"])
      if existing.present?
        Seeds.log("#{text} DUPLICATE: #{existing.id}")
        return existing
      end

      url = get_url(data)
      Seeds.log("#{text} #{url}") if text.present?

      upload = Upload.create(
        uploader:    user,
        direct_url:  url,
        tag_string:  data["tags"].map { |category, tags| tags.map { |tag| "#{category}:#{tag}" } }.flatten.join(" "),
        source:      data["sources"].join("\n"),
        description: data["description"],
        rating:      data["rating"],
      )

      if upload.failed?
        raise(StandardError, "Failed to create upload: #{upload.status_message.presence || upload.status}")
      end

      if upload.errors.any?
        raise(StandardError, "Failed to create upload: #{upload.errors.full_messages}")
      end

      if upload.post&.errors&.any?
        raise(StandardError, "Failed to create post: #{upload.post.errors.full_messages}")
      end

      if upload.post.nil?
        Rails.logger.warn("Post is nil for upload #{upload.id}\n\n#{upload.status_message.presence || upload.status}\n\n#{upload.errors.full_messages.join("\n")}")
      end

      upload.post
    end

    def get_related_posts(post, from = [post["id"]])
      posts = []
      ids = Set.new

      if !post["relationships"]["parent_id"].nil? && from.exclude?(post["relationships"]["parent_id"])
        ids << post["relationships"]["parent_id"]
      end

      unless post["relationships"]["children"].empty?
        ids.merge(post["relationships"]["children"].reject { |id| from.include?(id) })
      end

      return posts if ids.empty?

      related = fetch_posts(%W[id:#{ids.to_a.join(',')}], ids.length)
      posts.concat(related)

      related.each do |p|
        posts.concat(get_related_posts(p, from + ids.to_a + posts.pluck("id")))
      end

      posts
    end

    def process_related_posts(ogpost, text: nil)
      related = get_related_posts(ogpost)
      all = [ogpost, *related]

      return if related.empty?

      Seeds.log("Got #{related.length} related posts for ##{ogpost['id']}")

      local = {}
      remote = {}
      posts = []
      all.each_with_index do |p, i|
        post = process_post(p, text: "#{text}[pc:#{i + 1}/#{all.length}]", relationships: false)
        next if post.nil?
        posts << post
        remote[p["id"]] = post.id
        local[post.id] = p["id"]
      end

      local.each_key do |p|
        rp = all.find { |ps| ps["id"] == local[p] }
        post = posts.find { |ps| ps.id == p }
        parent = remote[rp["relationships"]["parent_id"]]
        next if  parent.nil? || post.parent_id == parent
        post.update!(parent_id: parent)
      end
    end

    def get_url(post)
      return post["file"]["url"] unless post["file"]["url"].nil?
      Seeds.log("post #{post['id']} returned a nil url, attempting to reconstruct url.")
      return "https://static1.e621.net/data/#{post['file']['md5'][0..1]}/#{post['file']['md5'][2..3]}/#{post['file']['md5']}.#{post['file']['ext']}" if e621?
      "https://static.gayfur.city/posts/#{post['file']['md5'][0..1]}/#{post['file']['md5'][2..3]}/#{post['file']['md5']}.#{post['file']['ext']}"
    end

    def randseed
      @randseed ||= SecureRandom.hex(16)
    end

    def per_page_limit
      e621? ? 320 : MAX_PER_PAGE
    end

    def fetch_related_posts?
      Seeds.read_resources["fetch_related_posts"].to_s.truthy?
    end

    def fetch_pools?
      Seeds.read_resources["fetch_pools"].to_s.truthy?
    end

    def safe?
      Seeds.read_resources["safe"].to_s.truthy?
    end

    delegate(:e621?, to: :Seeds)

    def fetch_posts(tags, limit = per_page_limit, page = 1)
      tags << "rating:s" if safe?
      posts = Seeds.api_request("/posts.json?limit=#{[per_page_limit, limit].min}&tags=#{tags.join('%20')}&page=#{page}")
      posts = posts["posts"] if e621?
      posts.reject(&method(:filter_post))
    end

    def filter_post(post)
      post["flags"]["deleted"] || post["file"]["ext"] == "swf"
    end

    def get_posts(&block)
      page = 1
      remaining = @limit
      while remaining > 0
        posts = fetch_posts(@tags, remaining, page)
        if posts.empty? # Rather than checking `length == per_page_limit`, we fetch another page and check empty due to fetch rejecting deleted & flash
          Seeds.log("Ran out of posts to fetch, exiting.")
          break
        end
        block.call(posts, page)
        remaining -= posts.length
        page += 1
      end
    end

    def fetch_pool(id)
      pool = Seeds.api_request("/pools/#{id}.json")
      Seeds::Posts::Pool.new(**pool.transform_keys(&:to_sym))
    end

    def process_post_pools(ogpost, text: nil)
      remote_pools = []
      remote_posts = []
      local_pools = []
      local_posts = []
      posts_by_pool = {}
      ogpost["pools"].reject { |id| handled_pools.include?(id) }.each do |id|
        pool = fetch_pool(id)
        remote_pools << pool
      end

      return if remote_pools.empty?

      remote_pools.map(&:post_ids).flatten.uniq.each_slice(100) do |post_ids|
        remote_posts += fetch_posts(%W[id:#{post_ids.join(',')}], 100)
      end

      existing = Post.joins(:media_asset).where("upload_media_assets.md5": remote_posts.map { |p| p["file"]["md5"] })
      ep = existing.index_by(&:md5)

      remote_pools.each_with_index do |ogpool, rpi|
        @handled_pools.push(ogpool.id) # ensure we don't recurse here again
        rp = remote_posts.select { |p| ogpool.post_ids.include?(p["id"]) }
        rmd5 = rp.map { |p| p["file"]["md5"] }
        lp = ep.select { |k| rmd5.include?(k) }.values
        rp.reject! { |p| lp.map(&:md5).include?(p["file"]["md5"]) }
        rp.each_with_index { |post, i| lp << process_post(post, text: "#{text}[pool:#{rpi + 1}/#{remote_pools.count}][#{i + 1}/#{ogpool.post_ids.length}]") }
        lp.sort_by! { |p| rmd5.index(p.md5) }.reverse!
        local_posts += lp
        posts_by_pool[ogpool.id] = lp
        local_pools << create_pool(ogpool, lp)
      end
    end

    def create_pool(ogpool, posts)
      pool = ::Pool.find_by(name: ogpool.name)
      if pool
        Seeds.log("Updating pool #{ogpool.name} for #{posts.count} posts")
        pool.update!(description: ogpool.description, is_active: ogpool.is_active, post_ids: posts.map(&:id))
      else
        Seeds.log("Creating pool #{ogpool.name} for #{posts.count} posts")
        pool = ::Pool.create!(name: ogpool.name, description: ogpool.description, is_active: ogpool.is_active, post_ids: posts.map(&:id))
      end
      pool
    end

    def handled_pools
      @handled_pools ||= []
    end
  end
end

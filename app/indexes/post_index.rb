# frozen_string_literal: true

module PostIndex
  PostData = Struct.new(:id, :pool_ids, :post_set_ids, :commenter_ids, :comment_count, :noter_ids, :note_bodies, :fav_user_ids, :upvote_user_ids, :downvote_user_ids, :child_post_ids, :disapprover_ids, :disapproval_count, :deleter_id, :deletion_reason, :has_pending_replacements, :has_verified_artist, :file_size, :image_width, :image_height, :duration, :framecount, :md5, :file_ext, keyword_init: true) do
    def initialize(**options)
      %i[pool_ids post_set_ids commenter_ids noter_ids note_bodies fav_user_ids upvote_user_ids downvote_user_ids child_post_ids disapprover_ids].each do |key|
        next unless options.key?(key)
        value = parse_pg_array(options[key])
        if key.to_s.ends_with?("_ids") && !value.nil?
          options[key] = value.map(&:to_i)
        else
          options[key] = value
        end
      end
      super
    end

    def parse_pg_array(str)
      return [] if str.blank?
      content = str[1..-2]
      elements = content.scan(/"([^"]*)"|([^,]+)/).map { |quoted, unquoted| quoted || unquoted }
      elements.map { |e| e == "NULL" ? nil : e }
    end
  end

  def self.included(base)
    base.document_store.index = {
      settings: {
        index: {
          number_of_shards:   ENV.fetch("GAYFURCITY_ELASTICSEARCH_POST_INDEX_SHARDS", 5).to_i,
          number_of_replicas: ENV.fetch("GAYFURCITY_ELASTICSEARCH_POST_INDEX_REPLICAS", 0).to_i,
          max_result_window:  ENV.fetch("GAYFURCITY_ELASTICSEARCH_POST_INDEX_RESULTS", 500_000).to_i,
        },
      },
      mappings: {
        dynamic:    false,
        properties: {
          created_at:               { type: "date" },
          updated_at:               { type: "date" },
          commented_at:             { type: "date" },
          comment_bumped_at:        { type: "date" },
          noted_at:                 { type: "date" },
          id:                       { type: "integer" },
          up_score:                 { type: "integer" },
          down_score:               { type: "integer" },
          score:                    { type: "integer" },
          fav_count:                { type: "integer" },
          tag_count:                { type: "integer" },
          change_seq:               { type: "long" },

          tag_count_general:        { type: "integer" },
          tag_count_artist:         { type: "integer" },
          tag_count_character:      { type: "integer" },
          tag_count_copyright:      { type: "integer" },
          tag_count_meta:           { type: "integer" },
          tag_count_species:        { type: "integer" },
          tag_count_invalid:        { type: "integer" },
          tag_count_lore:           { type: "integer" },
          tag_count_contributor:    { type: "integer" },
          tag_count_gender:         { type: "integer" },
          tag_count_important:      { type: "integer" },
          comment_count:            { type: "integer" },
          disapproval_count:        { type: "integer" },

          file_size:                { type: "integer" },
          parent:                   { type: "integer" },
          pools:                    { type: "integer" },
          sets:                     { type: "integer" },
          commenters:               { type: "integer" },
          noters:                   { type: "integer" },
          faves:                    { type: "integer" },
          upvotes:                  { type: "integer" },
          downvotes:                { type: "integer" },
          children:                 { type: "integer" },
          uploader:                 { type: "integer" },
          approver:                 { type: "integer" },
          disapprovers:             { type: "integer" },
          deleter:                  { type: "integer" },
          width:                    { type: "integer" },
          height:                   { type: "integer" },
          mpixels:                  { type: "float" },
          aspect_ratio:             { type: "float" },
          duration:                 { type: "float" },
          framecount:               { type: "integer" },
          views:                    { type: "integer" },

          tags:                     { type: "keyword" },
          md5:                      { type: "keyword" },
          rating:                   { type: "keyword" },
          file_ext:                 { type: "keyword" },
          source:                   { type: "keyword" },
          description:              { type: "text" },
          notes:                    { type: "text" },
          del_reason:               { type: "keyword" },
          qtags:                    { type: "keyword" },

          rating_locked:            { type: "boolean" },
          note_locked:              { type: "boolean" },
          status_locked:            { type: "boolean" },
          flagged:                  { type: "boolean" },
          pending:                  { type: "boolean" },
          deleted:                  { type: "boolean" },
          appealed:                 { type: "boolean" },
          unlisted:                 { type: "boolean" },
          in_progress:              { type: "boolean" },
          has_children:             { type: "boolean" },
          has_pending_replacements: { type: "boolean" },
          artverified:              { type: "boolean" },
        },
      },
    }

    base.document_store.extend(ClassMethods)
  end

  module ClassMethods
    # Denormalizing the input can be made significantly more
    # efficient when processing large numbers of posts.
    def import(options = {})
      batch_size = options[:batch_size] || 1000

      relation = all
      relation = relation.where(id: (options[:from])..) if options[:from]
      relation = relation.where(id: ..(options[:to]))   if options[:to]
      relation = relation.where(options[:query])           if options[:query]

      # PG returns {array,results,like,this}, so we need to parse it

      relation.find_in_batches(batch_size: batch_size) do |batch|
        post_ids = batch.map(&:id)

        data                     = get_data(Post.where(id: post_ids))
        pool_ids                 = data.to_h { |d| [d.id, d.pool_ids] }
        post_set_ids             = data.to_h { |d| [d.id, d.post_set_ids] }
        commenter_ids            = data.to_h { |d| [d.id, d.commenter_ids] }
        comment_counts           = data.to_h { |d| [d.id, d.comment_count] }
        noter_ids                = data.to_h { |d| [d.id, d.noter_ids] }
        note_bodies              = data.to_h { |d| [d.id, d.note_bodies] }
        fav_user_ids             = data.to_h { |d| [d.id, d.fav_user_ids] }
        upvote_user_ids          = data.to_h { |d| [d.id, d.upvote_user_ids] }
        downvote_user_ids        = data.to_h { |d| [d.id, d.downvote_user_ids] }
        child_post_ids           = data.to_h { |d| [d.id, d.child_post_ids] }
        disapprover_ids          = data.to_h { |d| [d.id, d.disapprover_ids] }
        disapproval_counts       = data.to_h { |d| [d.id, d.disapproval_count] }
        deleter_ids              = data.to_h { |d| [d.id, d.deleter_id] }
        deletion_reasons         = data.to_h { |d| [d.id, d.deletion_reason] }
        has_pending_replacements = data.to_h { |d| [d.id, d.has_pending_replacements] }
        has_verified_artist      = data.to_h { |d| [d.id, d.has_verified_artist] }
        file_sizes               = data.to_h { |d| [d.id, d.file_size] }
        image_widths             = data.to_h { |d| [d.id, d.image_width] }
        image_heights            = data.to_h { |d| [d.id, d.image_height] }
        durations                = data.to_h { |d| [d.id, d.duration] }
        framecounts              = data.to_h { |d| [d.id, d.framecount] }
        md5s                     = data.to_h { |d| [d.id, d.md5] }
        file_exts                = data.to_h { |d| [d.id, d.file_ext] }
        views                    = Reports.get_views_for_posts(post_ids)

        empty = []
        batch.map! do |p|
          index_options = {
            comment_count:            comment_counts[p.id] || 0,
            pools:                    pool_ids[p.id] || empty,
            sets:                     post_set_ids[p.id] || empty,
            faves:                    fav_user_ids[p.id] || empty,
            upvotes:                  upvote_user_ids[p.id] || empty,
            downvotes:                downvote_user_ids[p.id] || empty,
            children:                 child_post_ids[p.id] || empty,
            commenters:               commenter_ids[p.id] || empty,
            noters:                   noter_ids[p.id] || empty,
            notes:                    note_bodies[p.id] || empty,
            deleter:                  deleter_ids[p.id],
            disapprovers:             disapprover_ids[p.id] || empty,
            del_reason:               deletion_reasons[p.id],
            has_pending_replacements: has_pending_replacements[p.id] || false,
            disapproval_count:        disapproval_counts[p.id] || 0,
            artverified:              has_verified_artist[p.id] || false,
            views:                    views[p.id] || 0,
            file_size:                file_sizes[p.id] || 0,
            width:                    image_widths[p.id] || 0,
            height:                   image_heights[p.id] || 0,
            duration:                 durations[p.id] || 0,
            framecount:               framecounts[p.id] || 0,
            md5:                      md5s[p.id],
            file_ext:                 file_exts[p.id],
          }

          {
            index: {
              _id:  p.id,
              data: p.as_indexed_json(index_options),
            },
          }
        end

        client.bulk({
          index: index_name,
          body:  batch,
        })
      end
    end

    def get_data(relation = Post.all)
      sql = Post
            .with(linked_artists: Artist.select("artists.linked_user_id", "ARRAY_AGG(artists.name) AS artist_names").where.not(linked_user_id: nil).group(:linked_user_id))
            .select("posts.id",
                    "pools_agg.pool_ids",
                    "post_sets_agg.post_set_ids",
                    "comments_agg.commenter_ids",
                    "comments_agg.comment_count",
                    "notes_agg.noter_ids", "notes_agg.note_bodies",
                    "favorites_agg.fav_user_ids",
                    "post_votes_agg.upvote_user_ids", "post_votes_agg.downvote_user_ids",
                    "child_posts_agg.child_post_ids",
                    "post_disapprovals_agg.disapprover_ids", "post_disapprovals_agg.disapproval_count",
                    "last_flag.deleter_id, last_flag.deletion_reason",
                    "post_replacements_agg.has_pending_replacements",
                    "verified_artist_agg.has_verified_artist",
                    "upload_media_assets.file_size",
                    "upload_media_assets.image_width",
                    "upload_media_assets.image_height",
                    "upload_media_assets.duration",
                    "upload_media_assets.framecount",
                    "upload_media_assets.md5",
                    "upload_media_assets.file_ext")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(pools.id) AS pool_ids FROM pools WHERE posts.id = ANY(pools.post_ids)) pools_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(post_sets.id) AS post_set_ids FROM post_sets WHERE posts.id = ANY(post_sets.post_ids)) post_sets_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(comments.creator_id) AS commenter_ids, COUNT(comments.id) AS comment_count FROM comments WHERE comments.post_id = posts.id AND comments.is_hidden = FALSE) comments_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(notes.creator_id) noter_ids, ARRAY_AGG(notes.body) AS note_bodies FROM notes WHERE notes.post_id = posts.id AND notes.is_active = TRUE) notes_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(favorites.user_id) AS fav_user_ids FROM favorites WHERE favorites.post_id = posts.id) favorites_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(post_votes.user_id) FILTER (WHERE post_votes.score > 0) as upvote_user_ids, ARRAY_AGG(post_votes.user_id) FILTER (WHERE post_votes.score < 0) AS downvote_user_ids FROM post_votes WHERE post_votes.post_id = posts.id) post_votes_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(child_posts.id) AS child_post_ids FROM posts AS child_posts WHERE child_posts.parent_id = posts.id) child_posts_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT ARRAY_AGG(post_disapprovals.user_id) AS disapprover_ids, COUNT(post_disapprovals.user_id) AS disapproval_count FROM post_disapprovals WHERE post_disapprovals.post_id = posts.id) post_disapprovals_agg ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT creator_id as deleter_id, reason as deletion_reason FROM post_flags WHERE post_flags.post_id = posts.id AND post_flags.is_resolved = FALSE and post_flags.is_deletion = TRUE ORDER BY id DESC LIMIT 1) last_flag ON TRUE")
            .joins("LEFT JOIN LATERAL (SELECT EXISTS(SELECT 1 FROM post_replacements WHERE post_replacements.post_id = posts.id AND post_replacements.status = 'pending') as has_pending_replacements) post_replacements_agg ON TRUE")
            .joins("LEFT JOIN linked_artists ON linked_artists.linked_user_id = posts.uploader_id")
            .joins("LEFT JOIN LATERAL (SELECT EXISTS(SELECT 1 FROM unnest(string_to_array(posts.tag_string, ' ')) AS tag WHERE tag = ANY(linked_artists.artist_names)) AS has_verified_artist) verified_artist_agg ON TRUE")
            .joins("LEFT JOIN upload_media_assets ON upload_media_assets.id = posts.upload_media_asset_id")
            .order(id: :asc)
            .merge(relation)
            .to_sql
      Post.connection.execute(sql).map { |d| PostData.new(**d.transform_keys(&:to_sym)) }
    end

    def import_views(options = {})
      batch_size = options[:batch_size] || 10_000

      relation = all
      relation = relation.where(id: (options[:from])..) if options[:from]
      relation = relation.where(id: ..(options[:to]))   if options[:to]
      relation = relation.where(options[:query])           if options[:query]

      relation.find_in_batches(batch_size: batch_size) do |batch|
        post_ids = batch.map(&:id)
        views = Reports.get_views_for_posts(post_ids)
        batch.map! do |p|
          {
            update: {
              _id:  p.id,
              data: {
                doc: { views: views[p.id] || 0 },
              },
            },
          }
        end

        client.bulk({
          index: index_name,
          body:  batch,
        })
      end
    end
  end

  def as_indexed_json(options = {})
    options_or_get = ->(key, get) { options.key?(key) ? options[key] : get.call }
    width = options_or_get.call(:width, -> { image_width })
    height = options_or_get.call(:height, -> { image_height })
    {
      created_at:               created_at,
      updated_at:               updated_at,
      commented_at:             last_commented_at,
      comment_bumped_at:        last_comment_bumped_at,
      noted_at:                 last_noted_at,
      id:                       id,
      up_score:                 up_score,
      down_score:               down_score,
      score:                    score,
      fav_count:                fav_count,
      tag_count:                tag_count,
      change_seq:               change_seq,

      tag_count_general:        tag_count_general,
      tag_count_artist:         tag_count_artist,
      tag_count_character:      tag_count_character,
      tag_count_copyright:      tag_count_copyright,
      tag_count_meta:           tag_count_meta,
      tag_count_species:        tag_count_species,
      tag_count_lore:           tag_count_lore,
      tag_count_invalid:        tag_count_invalid,
      tag_count_contributor:    tag_count_contributor,
      tag_count_gender:         tag_count_gender,
      tag_count_important:      tag_count_important,
      comment_count:            options_or_get.call(:comment_count, -> { comment_count }),
      disapproval_count:        options_or_get.call(:disapproval_count, -> { ::PostDisapproval.where(post_id: id).pluck(:user_id).size }),

      file_size:                options_or_get.call(:file_size, -> { file_size }),
      parent:                   parent_id,
      pools:                    options_or_get.call(:pools, -> { ::Pool.where("? = ANY(post_ids)", id).pluck(:id) }),
      sets:                     options_or_get.call(:sets, -> { ::PostSet.where("? = ANY(post_ids)", id).pluck(:id) }),
      commenters:               options_or_get.call(:commenters, -> { ::Comment.not_deleted.where(post_id: id).pluck(:creator_id) }),
      noters:                   options_or_get.call(:noters, -> { ::Note.active.where(post_id: id).pluck(:creator_id) }),
      faves:                    options_or_get.call(:faves, -> { ::Favorite.where(post_id: id).pluck(:user_id) }),
      upvotes:                  options_or_get.call(:upvotes, -> { ::PostVote.where(post_id: id).where("score > 0").pluck(:user_id) }),
      downvotes:                options_or_get.call(:downvotes, -> { ::PostVote.where(post_id: id).where("score < 0").pluck(:user_id) }),
      children:                 options_or_get.call(:children, -> { ::Post.where(parent_id: id).pluck(:id) }),
      notes:                    options_or_get.call(:notes, -> { ::Note.active.where(post_id: id).pluck(:body) }),
      uploader:                 uploader_id,
      approver:                 approver_id,
      disapprovers:             options_or_get.call(:disapprovers, -> { ::PostDisapproval.where(post_id: id).pluck(:user_id) }),
      deleter:                  options_or_get.call(:deleter, -> { ::PostFlag.where(post_id: id, is_resolved: false, is_deletion: true).order(id: :desc).first&.creator_id }),
      del_reason:               options_or_get.call(:del_reason, -> { ::PostFlag.where(post_id: id, is_resolved: false, is_deletion: true).order(id: :desc).first&.reason&.downcase }),
      width:                    width,
      height:                   height,
      mpixels:                  width && height ? (width.to_f * height / 1_000_000).round(2) : 0.0,
      aspect_ratio:             width && height ? (width.to_f / [height, 1].max).round(10) : 1.0,
      duration:                 options_or_get.call(:duration, -> { duration }),
      framecount:               options_or_get.call(:framecount, -> { framecount }),
      views:                    options_or_get.call(:views, -> { Reports.get_post_views(id) }),

      tags:                     tag_string.split,
      md5:                      options_or_get.call(:md5, -> { md5 }),
      rating:                   rating,
      file_ext:                 options_or_get.call(:file_ext, -> { file_ext }),
      source:                   source_array.map(&:downcase),
      description:              description.presence,
      qtags:                    qtags,

      rating_locked:            is_rating_locked,
      note_locked:              is_note_locked,
      status_locked:            is_status_locked,
      flagged:                  is_flagged,
      pending:                  is_pending,
      deleted:                  is_deleted,
      appealed:                 is_appealed,
      unlisted:                 is_unlisted,
      in_progress:              is_in_progress,
      has_children:             has_children,
      has_pending_replacements: options_or_get.call(:has_pending_replacements, -> { replacements.pending.any? }),
      artverified:              options_or_get.call(:artverified, -> { uploader_linked_artists.any? }),
    }
  end
end

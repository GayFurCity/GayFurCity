# frozen_string_literal: true

class PostQueryBuilder
  attr_accessor(:query_string, :user)

  def initialize(query_string, user)
    @query_string = query_string
    @user = user
  end

  def add_tag_string_search_relation(tags, relation)
    if tags[:must].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') @> ARRAY[?]", tags[:must])
    end
    if tags[:must_not].any?
      relation = relation.where("NOT(string_to_array(posts.tag_string, ' ') && ARRAY[?])", tags[:must_not])
    end
    if tags[:should].any?
      relation = relation.where("string_to_array(posts.tag_string, ' ') && ARRAY[?]", tags[:should])
    end

    relation
  end

  def add_array_range_relation(relation, values, field, &block)
    return relation unless values
    if block_given?
      if block.arity == 1
        relation = block.call(relation)
      else
        relation = relation.instance_eval(&block)
      end
    end
    values.each do |value|
      relation = relation.add_range_relation(value, field)
    end
    relation
  end

  def search
    q = TagQuery.new(query_string, user)
    relation = Post.all

    relation = add_array_range_relation(relation, q[:post_id], "posts.id")
    relation = add_array_range_relation(relation, q[:mpixels], "upload_media_assets.image_width * upload_media_assets.image_height / 1000000.0") { joins(:media_asset) }
    relation = add_array_range_relation(relation, q[:ratio], "ROUND(1.0 * upload_media_assets.image_width / GREATEST(1, upload_media_assets.image_height), 2)") { joins(:media_asset) }
    relation = add_array_range_relation(relation, q[:width], "upload_media_assets.image_width") { joins(:media_asset) }
    relation = add_array_range_relation(relation, q[:height], "upload_media_assets.image_height") { joins(:media_asset) }
    relation = add_array_range_relation(relation, q[:score], "posts.score")
    relation = add_array_range_relation(relation, q[:fav_count], "posts.fav_count")
    relation = add_array_range_relation(relation, q[:framecount], "posts.framecount")
    relation = add_array_range_relation(relation, q[:filesize], "upload_media_assets.file_size") { joins(:media_asset) }
    relation = add_array_range_relation(relation, q[:change_seq], "posts.change_seq")
    relation = add_array_range_relation(relation, q[:date], "posts.created_at")
    relation = add_array_range_relation(relation, q[:age], "posts.created_at")
    TagCategory.category_names.each do |category|
      relation = add_array_range_relation(relation, q[:"#{category}_tag_count"], "posts.tag_count_#{category}")
    end
    relation = add_array_range_relation(relation, q[:post_tag_count], "posts.tag_count")

    TagQuery::COUNT_METATAGS.each do |column|
      relation = add_array_range_relation(relation, q[column.to_sym], "posts.#{column}")
    end

    if q[:md5]
      relation = relation.joins(:media_asset).where("upload_media_assets.md5": q[:md5])
    end

    if q[:status] == "pending"
      relation = relation.where("posts.is_pending": true)
    elsif q[:status] == "flagged"
      relation = relation.where("posts.is_flagged": true)
    elsif q[:status] == "appealed"
      # a regular join is used rather than left_joins, which eliminates checking that a post appeal is present
      relation = relation.joins(:appeals).where("post_appeals.status": :pending)
    elsif q[:status] == "modqueue"
      relation = relation.left_joins(:appeals) # required for both for enum conversion, and outside for structure
      relation = relation.where("posts.is_pending": true).or(relation.where("posts.is_flagged": true)).or(relation.where.not("post_appeals.id": nil).where("post_appeals.status": :pending))
    elsif q[:status] == "deleted"
      relation = relation.where("posts.is_deleted": true)
    elsif q[:status] == "unlisted"
      relation = relation.where("posts.is_unlisted": true)
    elsif q[:status] == "in_progress"
      relation = relation.where("posts.is_in_progress": true)
    elsif q[:status] == "active"
      relation = relation.where("posts.is_pending": false, "posts.is_deleted": false, "posts.is_flagged": false)
    elsif %w[all any].include?(q[:status])
      # do nothing
    elsif q[:status_must_not] == "pending"
      relation = relation.where("posts.is_pending": false)
    elsif q[:status_must_not] == "flagged"
      relation = relation.where("posts.is_flagged": false)
    elsif q[:status_must_not] == "appealed"
      relation = relation.left_joins(:appeals) # required for both for enum conversion
      relation = relation.where("post_appeals.id": nil).or(relation.where.not("post_appeals.status": :pending))
    elsif q[:status_must_not] == "modqueue"
      relation = relation.left_joins(:appeals) # required for both for enum conversion, and outside for structure
      relation = relation.where("posts.is_pending": false, "posts.is_flagged": false).and(relation.where("post_appeals.id": nil).or(relation.where.not("post_appeals.status": :pending)))
    elsif q[:status_must_not] == "deleted"
      relation = relation.where("posts.is_deleted": false)
    elsif q[:status_must_not] == "unlisted"
      relation = relation.where("posts.is_unlisted": false)
    elsif q[:status_must_not] == "in_progress"
      relation = relation.where("posts.is_in_progress": false)
    elsif q[:status_must_not] == "active"
      relation = relation.where("posts.is_pending": true).or(relation.where("posts.is_deleted": true)).or(relation.where("posts.is_flagged": true))
    end

    q[:filetype]&.each do |filetype|
      relation = relation.joins(:media_asset).where("upload_media_assets.file_ext": filetype)
    end

    q[:filetype_must_not]&.each do |filetype|
      relation = relation.joins(:media_asset).where.not("upload_media_assets.file_ext": filetype)
    end

    if q[:pool] == "none"
      relation = relation.where("posts.pool_string": "")
    elsif q[:pool] == "any"
      relation = relation.where.not("posts.pool_string": "")
    end

    q[:uploader_ids]&.each do |uploader_id|
      relation = relation.where("posts.uploader_id": uploader_id)
    end

    q[:uploader_ids_must_not]&.each do |uploader_id|
      relation = relation.where.not("posts.uploader_id": uploader_id)
    end

    if q[:approver] == "any"
      relation = relation.where.not("posts.approver_id": nil)
    elsif q[:approver] == "none"
      relation = relation.where("posts.approver_id": nil)
    end

    q[:approver_ids]&.each do |approver_id|
      relation = relation.where("posts.approver_id": approver_id)
    end

    q[:approver_ids_must_not]&.each do |approver_id|
      relation = relation.where.not("posts.approver_id": approver_id)
    end

    if q[:commenter] == "any"
      relation = relation.where.not("posts.last_commented_at": nil)
    elsif q[:commenter] == "none"
      relation = relation.where("posts.last_commented_at": nil)
    end

    if q[:noter] == "any"
      relation = relation.where.not("posts.last_noted_at": nil)
    elsif q[:noter] == "none"
      relation = relation.where("posts.last_noted_at": nil)
    end

    if q[:parent] == "none"
      relation = relation.where("posts.parent_id": nil)
    elsif q[:parent] == "any"
      relation = relation.where.not("posts.parent_id": nil)
    end

    q[:parent_ids]&.each do |parent_id|
      relation = relation.where("posts.parent_id": parent_id)
    end

    q[:parent_ids_must_not]&.each do |parent_id|
      relation = relation.where.not("posts.parent_id": parent_id)
    end

    if q[:qtags] == "none"
      relation = relation.where("posts.qtags": [])
    elsif q[:qtags] == "any"
      relation = relation.where.not("posts.qtags": [])
    end

    if q[:qtag]
      relation = relation.where.contains("posts.qtags": q[:qtag])
    elsif q[:qtag_must_not]
      # active_record_extended does not support negating contains
      relation = relation.where.not(Post.arel_table[:qtags].contains(q[:qtag_must_not]))
    end

    if q[:child] == "none"
      relation = relation.where("posts.has_children": false)
    elsif q[:child] == "any"
      relation = relation.where("posts.has_children": true)
    end

    q[:rating]&.each do |rating|
      relation = relation.where("posts.rating = ?", rating)
    end

    q[:rating_must_not]&.each do |rating|
      relation = relation.where("posts.rating = ?", rating)
    end

    add_tag_string_search_relation(q[:tags], relation)
  end
end

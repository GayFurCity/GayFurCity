# frozen_string_literal: true

class PostsController < ApplicationController
  respond_to(:html, :json)
  before_action(:ensure_lockdown_disabled, except: %i[index show show_seq random uploaders search search_definitions])
  # Combining if: with only: here would NOT AND them - only:/except: attach as their own
  # independent "unless" condition alongside if:, so `only: %i[search]` alone would skip CSRF
  # for every request to :search regardless of format. The action check has to live inside the
  # if: proc itself instead.
  skip_forgery_protection(if: -> { action_name == "search" && request.post? && request.format.json? })

  def index
    if params[:md5].present?
      @post = authorize(Post.joins(:media_asset).find_by!("upload_media_assets.md5": params[:md5]))
      respond_with(@post) do |format|
        format.html { redirect_to(@post) }
        format.json { render(json: [@post].to_json) }
      end
    else
      authorize(Post)
      @post_set = PostSets::Post.new(tag_query, params[:page], limit: params[:limit], random: params[:random], current_user: CurrentUser.user)
      @post_set.load_view_counts! # force load view counts all at once
      @votes = PostVote.where(user_id: CurrentUser.user.id, post_id: @post_set.posts.map(&:id))
      @posts = PostsDecorator.decorate_collection(@post_set.posts)
      respond_with(@posts) do |format|
        format.json do
          render(json: @post_set.api_posts)
        end
        format.atom
      end
    end
  end

  def search
    authorize(Post)

    if request.post?
      @tags = PostSearch::QueryBuilder.build(params[:search])
      respond_to do |format|
        format.html { redirect_to(posts_path(tags: @tags)) }
        format.json { render(json: { tags: @tags }) }
      end
    else
      @search_form = PostSearch::FormParser.parse(params[:tags])
      respond_to do |format|
        format.html
        format.json { render(json: @search_form) }
      end
    end
  end

  # The PostSearch::Fields DSL itself, for API/script consumers building their own search UI.
  def search_definitions
    authorize(Post, :search?)
    render(json: { categories: PostSearch::Fields.categories, fields: PostSearch::Fields.fields.map(&:to_h) })
  end

  def show
    @post = authorize(Post.find(params[:id]))

    raise(User::PrivilegeError, "Post unavailable") unless Security::Lockdown.post_visible?(@post, CurrentUser.user)

    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.user.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, include_deleted: include_deleted, want_parent: true, current_user: CurrentUser.user)
    @children_post_set = PostSets::PostRelationship.new(@post.id, include_deleted: include_deleted, want_parent: false, current_user: CurrentUser.user)
    @comment_votes = {}
    @comment_votes = CommentVote.for_comments_and_user(@post.comments.visible(CurrentUser.user).map(&:id), CurrentUser.user.id) if request.format.html?

    respond_with(@post)
  end

  def show_seq
    authorize(Post)
    @post = PostSearchContext.new(params, CurrentUser.user).post
    include_deleted = @post.is_deleted? || (@post.parent_id.present? && @post.parent.is_deleted?) || CurrentUser.user.is_approver?
    @parent_post_set = PostSets::PostRelationship.new(@post.parent_id, include_deleted: include_deleted, want_parent: true, current_user: CurrentUser.user)
    @children_post_set = PostSets::PostRelationship.new(@post.id, include_deleted: include_deleted, want_parent: false, current_user: CurrentUser.user)
    @comment_votes = {}
    @comment_votes = CommentVote.for_comments_and_user(@post.comments.visible(CurrentUser.user).map(&:id), CurrentUser.user.id) if request.format.html?
    @fixup_post_url = true

    respond_with(@post) do |fmt|
      fmt.html { render("posts/show") }
    end
  end

  def update
    @post = authorize(Post.find(params[:id]))
    ensure_can_edit(@post)

    pparams = permitted_attributes(@post)
    pparams.delete(:tag_string) if pparams[:tag_string_diff].present?
    pparams.delete(:source) if pparams[:source_diff].present?
    @post.update_with_current(:updater, pparams)
    respond_with_post_after_update(@post)
  end

  def revert
    @post = authorize(Post.find(params[:id]))
    ensure_can_edit(@post)
    @version = @post.versions.find(params[:version_id])

    @post.revert_to!(@version, CurrentUser.user)

    respond_with(@post, &:js)
  end

  def copy_notes
    @post = authorize(Post.find(params[:id]))
    ensure_can_edit(@post)
    @other_post = Post.find(params[:other_post_id].to_i)
    raise(User::PrivilegeError, "post ##{@other_post.id} is edit restricted") unless policy(@other_post).min_level?
    @post.copy_notes_to(@other_post, CurrentUser.user)

    if @post.errors.any?
      @error_message = @post.errors.full_messages.join("; ")
      render(json: { success: false, reason: @error_message }.to_json, status: :bad_request)
    else
      head(:no_content)
    end
  end

  def random
    authorize(Post)
    tags = params[:tags] || ""
    @post = Post.tag_match_current("#{tags} order:random").limit(1).first
    raise(ActiveRecord::RecordNotFound) if @post.nil?
    respond_with(@post) do |format|
      format.html { redirect_to(post_path(@post, tags: params[:tags])) }
    end
  end

  def mark_as_translated
    @post = authorize(Post.find(params[:id]))
    ensure_can_edit(@post)
    @post.mark_as_translated(permitted_attributes(@post))
    respond_with_post_after_update(@post)
  end

  def update_iqdb
    @post = authorize(Post.find(params[:id]))
    @post.update_iqdb_async
    respond_with_post_after_update(@post)
  end

  def delete
    @post = authorize(Post.find(params[:id]))
    @reason = @post.pending_flag&.reason || ""
    @reason = "Inferior version/duplicate of post ##{@post.parent_id}" if @post.parent_id && @reason == ""
    @reason = "" if @reason =~ /uploading_guidelines/
  end

  def destroy
    @post = authorize(Post.find(params[:id]))
    if params[:commit] != "Cancel"
      @post.delete!(CurrentUser.user, params[:reason], move_favorites: params[:move_favorites]&.truthy?)
      @post.copy_sources_to_parent if params[:copy_sources]&.truthy?
      @post.copy_tags_to_parent if params[:copy_tags]&.truthy?
      @post.parent.save if params[:copy_tags]&.truthy? || params[:copy_sources]&.truthy?
    end
    respond_with(@post) do |format|
      format.html { redirect_to(post_path(@post)) }
    end
  end

  def undelete
    @post = authorize(Post.find(params[:id]))
    appeal = @post.is_appealed?
    @post.undelete!(CurrentUser.user)
    if appeal && request.format.html?
      notice("Post appeal accepted")
      return redirect_back_or_to(post_path(@post))
    end
    respond_with(@post)
  end

  def finish_in_progress
    @post = authorize(Post.find(params[:id]))
    @post.finish_in_progress!(CurrentUser.user)
    respond_with(@post)
  end

  def expunge
    @post = authorize(Post.find(params[:id]))
    @post.expunge!(CurrentUser.user, reason: params[:reason])
    respond_with(@post)
  end

  def regenerate_thumbnails
    @post = authorize(Post.find(params[:id]))
    raise(User::PrivilegeError, "Cannot regenerate variants on deleted images") if @post.is_deleted?
    @post.regenerate_image_variants
    respond_with(@post)
  end

  def regenerate_videos
    @post = authorize(Post.find(params[:id]))
    raise(User::PrivilegeError, "Cannot regenerate variants on deleted images") if @post.is_deleted?
    @post.regenerate_video_variants
    respond_with(@post)
  end

  def approve
    @post = authorize(Post.find(params[:id]))
    if @post.is_approvable?
      @post.approve!(CurrentUser.user)
      respond_to do |format|
        format.json
      end
    elsif @post.approver.present?
      flash[:notice] = "Post is already approved"
      render_expected_error(400, "Post is already approved") if request.format.json?
    else
      flash[:notice] = "You can't approve this post"
      render_expected_error(400, "You can't approve this post") if request.format.json?
    end
  end

  def unapprove
    @post = authorize(Post.find(params[:id]))
    if @post.is_unapprovable?(CurrentUser.user)
      @post.unapprove!(CurrentUser.user)
      respond_with(nil)
    else
      flash[:notice] = "You can't unapprove this post"
      render_expected_error(400, "You can't unapprove this post") if request.format.json?
    end
  end

  def uploaders
    @relation = authorize(Post).pending.search_uploaders(search_params(Post), CurrentUser.user).group(:uploader_id).reorder("COUNT(posts.uploader_id) DESC").paginate(params[:page], limit: params[:limit] || 20)
    @counts = @relation.count
    @users = User.where(id: @counts.keys)
  end

  def add_to_pool
    @post = authorize(Post.find(params[:id]))
    if params[:pool_id].present?
      @pool = Pool.find(params[:pool_id])
    else
      @pool = Pool.find_by!(name: params[:pool_name])
    end

    @pool.with_lock do
      @pool.add!(@post, CurrentUser.user)
      @pool.save
    end
    append_pool_to_session(@pool)
    respond_with(@pool, location: post_path(@post))
  end

  def remove_from_pool
    @post = authorize(Post.find(params[:id]))
    if params[:pool_id].present?
      @pool = Pool.find(params[:pool_id])
    else
      @pool = Pool.find_by!(name: params[:pool_name])
    end

    @pool.with_lock do
      @pool.remove!(@post, CurrentUser.user)
      @pool.save
    end
    respond_with(@pool, location: post_path(@post))
  end

  def favorites
    @post = authorize(Post.find(params[:id]))
    query = User.joins(:favorites)
    unless CurrentUser.user.is_moderator?
      query = query.where("bit_prefs & :value != :value", { value: User.flag_value_for("enable_privacy_mode") }).or(query.where(favorites: { user_id: CurrentUser.user.id }))
    end
    query = query.where(favorites: { post_id: @post.id })
    query = query.order("users.name asc")
    @users = query.paginate(params[:page], limit: params[:limit])
  end

  def frame
    post = Post.find(params[:id])
    frame = params[:frame].to_i
    return render_expected_error(400, "Invalid frame", format: :json) if params[:frame].blank?
    post.thumbnail_frame = frame
    if post.invalid?
      return render_expected_error(400, post.errors.full_messages.join("; "), format: :json)
    end
    path = post.file { |f| VideoResizer.extract_frame(f.path, frame) }
    File.open(path, "r") do |file|
      send_data(file.read, type: "image/webp", disposition: "inline")
    end
    File.delete(path)
  end

  def ai_check
    @post = authorize(Post.find(params[:id]))
    @post.ai_check! => { score:, reason: }
    if score < AdminConfig.ai_confidence_threshold
      notice("Post is not AI")
    else
      notice("Post is AI: #{reason} (score: #{score})  ")
    end
    redirect_back_or_to(post_path(@post))
  end

  private

  def tag_query
    params[:tags] || (params[:post] && params[:post][:tags])
  end

  def respond_with_post_after_update(post)
    respond_with(post) do |format|
      format.html do
        if post.warnings.any?
          warnings = post.warnings.full_messages.join(".\n \n")
          if warnings.length > 45_000
            Dmail.create_automated({
              to_id: CurrentUser.user.id,
              title: "Post update notices for post ##{post.id}",
              body:  "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings[0..45_000]}",
            })
            flash[:notice] = "What the heck did you even do to this poor post? That generated way too many warnings. But you get a dmail with most of them anyways"
          elsif warnings.length > 1500
            Dmail.create_automated({
              to_id: CurrentUser.user.id,
              title: "Post update notices for post ##{post.id}",
              body:  "While editing post ##{post.id} some notices were generated. Please review them below:\n\n#{warnings}",
            })
            flash[:notice] = "This edit created a LOT of notices. They have been dmailed to you. Please review them"
          else
            flash[:notice] = warnings
          end
        end

        if post.errors.any?
          @message = post.errors.full_messages.join("; ")
          if flash[:notice].present?
            flash[:notice] += "\n\n#{@message}"
          else
            flash[:notice] = @message
          end
        end
        response_params = { q: params[:tags_query], pool_id: params[:pool_id], post_set_id: params[:post_set_id] }
        response_params.compact_blank!
        redirect_to(post_path(post, response_params))
      end

      format.json do
        return render_expected_error(422, post.errors.full_messages.join("; ")) if post.errors.any?
        render(json: post)
      end
    end
  end

  def ensure_can_edit(_post)
    can_edit = CurrentUser.can_post_edit_with_reason
    raise(User::PrivilegeError, "Updater #{User.throttle_reason(can_edit)}") unless can_edit == true
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.uploads_disabled? && !CurrentUser.user.is_staff?
  end

  def append_pool_to_session(pool)
    recent_pool_ids = session[:recent_pool_ids].to_s.scan(/\d+/)
    recent_pool_ids << pool.id.to_s
    recent_pool_ids = recent_pool_ids.slice(1, 5) if recent_pool_ids.size > 5
    session[:recent_pool_ids] = recent_pool_ids.uniq.join(",")
  end
end

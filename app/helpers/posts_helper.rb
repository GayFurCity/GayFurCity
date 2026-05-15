# frozen_string_literal: true

module PostsHelper
  def discover_mode?
    params[:tags]&.include?("order:rank")
  end

  def next_page_url
    current_page = (params[:page] || 1).to_i
    url_for(nav_params_for(current_page + 1))
  end

  def prev_page_url
    current_page = (params[:page] || 1).to_i
    if current_page >= 2
      url_for(nav_params_for(current_page - 1))
    end
  end

  def post_source_tag(source)
    # Only allow http:// and https:// links. Disallow javascript: links.
    if source =~ %r{\Ahttps?://}i
      source_link = decorated_link_to(source.sub(%r{\Ahttps?://(?:www\.)?}i, ""), source, target: "_blank", rel: "nofollow noreferrer noopener")

      if CurrentUser.user.is_janitor?
        source_link = safe_join([source_link, "", link_to("»", posts_path(tags: "source:#{source.sub(%r{[^/]*$}, '')}"), rel: "nofollow")])
      end

      source_link
    elsif source.start_with?("-")
      tag.s(source[1..])
    else
      source
    end
  end

  def has_parent_message(post, parent_post_set)
    sibling_parts = []
    sibling_count = parent_post_set.children.count - 1
    if sibling_count > 0
      sibling_parts << " that has "
      text = sibling_count == 1 ? "a sibling" : "#{sibling_count} siblings"
      sibling_parts << link_to(text, posts_path(tags: "parent:#{post.parent_id}"))
    end

    safe_join([
      "Parent: ", link_to("post ##{post.parent_id}", post_path(id: post.parent_id)),
      (" (deleted)" if parent_post_set.parent.first.is_deleted?),
      *sibling_parts,
      " (", link_to("learn more", help_page_path(id: "post_relationships")), ") ",
      link_to("show »", "#", id: "has-parent-relationship-preview-link"),
    ])
  end

  def has_children_message(post, children_post_set)
    text = children_post_set.children.one? ? "1 child" : "#{children_post_set.children.count} children"
    safe_join([
      "Children: ", link_to(text, posts_path(tags: "parent:#{post.id}")),
      " (", link_to("learn more", help_page_path(id: "post_relationships")), ") ",
      link_to("show »", "#", id: "has-children-relationship-preview-link"),
    ])
  end

  def is_pool_selected?(pool)
    return false if params.key?(:q)
    return false if params.key?(:post_set_id)
    return false unless params.key?(:pool_id)
    params[:pool_id].to_i == pool.id
  end

  def is_post_set_selected?(post_set)
    return false if params.key?(:q)
    return false if params.key?(:pool_id)
    return false unless params.key?(:post_set_id)
    params[:post_set_id].to_i == post_set.id
  end

  def post_stats_section(post, views: nil)
    post_score_icon_positive = "↑"
    post_score_icon_negative = "↓"
    post_score_icon_neutral = "↕"
    post_score_icon = "#{post_score_icon_positive if post.score > 0}#{post_score_icon_negative if post.score < 0}#{post_score_icon_neutral if post.score == 0}"
    score = tag.span(class: "post-score-score post-score-classes-#{post.id} #{score_class(post.score)}") do
      icon = tag.span(post_score_icon, class: "post-score-icon-#{post.id}", data: { "icon-positive": post_score_icon_positive, "icon-negative": post_score_icon_negative, "icon-neutral": post_score_icon_neutral })
      amount = tag.span(post.score, class: "post-score-score-#{post.id}")
      icon + amount
    end
    favs = tag.span(class: "post-score-faves post-score-faves-classes-#{post.id}") do
      icon = tag.span("♥", class: "post-score-faves-icon-#{post.id}")
      amount = tag.span(post.fav_count, class: "post-score-faves-faves-#{post.id}")
      icon + amount
    end
    comments = tag.span("C#{post.visible_comment_count(CurrentUser)}", class: "post-score-comments")
    rating = tag.span(post.rating.upcase, class: "post-score-rating")
    views = tag.span(class: "post-score-views post-score-views-classes-#{post.id}") do
      icon = tag.i("", class: "fa-regular fa-eye")
      if views.is_a?(Array)
        type, unique, count = views
        amount = tag.span(" #{type == :daily ? 'D' : 'T'}#{'U' if unique}#{count || 0}", class: "post-score-views-views-#{post.id}")
      else

        amount = tag.span(" #{views == :daily ? 'D' : 'T'}#{'U' if CurrentUser.user.unique_views?}#{(views == :daily ? post.daily_views : post.total_views) || 0}", class: "post-score-views-views-#{post.id}")
      end
      icon + amount
    end
    tag.div(score + favs + comments + views + rating, class: "post-score", id: "post-score-#{post.id}")
  end

  def user_record_meta(user)
    positive = user.positive_feedback_count
    neutral = user.neutral_feedback_count
    negative = user.negative_feedback_count
    deleted = CurrentUser.user.is_staff? ? user.deleted_feedback_count : 0

    return "" if (positive + neutral + negative + deleted) == 0
    list = [
      (tag.span(positive, class: "user-feedback-positive") if positive > 0),
      (tag.span(neutral, class: "user-feedback-neutral") if neutral > 0),
      (tag.span(negative, class: "user-feedback-negative") if negative > 0),
      (tag.span(deleted, class: "user-feedback-deleted") if deleted > 0),
    ].compact

    link_to(safe_join(["(", *list, ")"]), user_feedbacks_path(search: { user_id: user.id }))
  end

  private

  def nav_params_for(page)
    query_params = params.except(:controller, :action, :id).merge(page: page).permit!
    { params: query_params }
  end

  def pretty_html_rating(post)
    rating_text = post.pretty_rating
    rating_class = "post-rating-text-#{rating_text.downcase}"
    tag.span(rating_text, id: "post-rating-text", class: rating_class)
  end

  def post_vote_block(post, vote, buttons: false)
    vote_score = vote || 0
    post_score = post.score

    up_tag = tag.a(
      tag.span("▲", class: "post-vote-up-#{post.id} " + confirm_score_class(vote_score, 1, buttons)),
      class: "post-vote-up-link",
      data:  { id: post.id },
    )
    down_tag = tag.a(
      tag.span("▼", class: "post-vote-down-#{post.id} " + confirm_score_class(vote_score, -1, buttons)),
      class: "post-vote-down-link",
      data:  { id: post.id },
    )
    if buttons
      score_tag = tag.span(post.score, class: "post-score-#{post.id} post-score #{score_class(post_score)}", title: "#{post.up_score} up/#{post.down_score} down")
      CurrentUser.user.can_post_vote? ? up_tag + score_tag + down_tag : ""
    else
      vote_block = tag.span(safe_join([" (", up_tag, " vote ", down_tag, ")"]))
      score_tag = tag.span(post.score, class: "post-score-#{post.id} post-score #{score_class(post_score)}", title: "#{post.up_score} up/#{post.down_score} down")
      score_tag + (CurrentUser.user.can_post_vote? ? vote_block : "")
    end
  end

  def score_class(score)
    return "score-neutral" if score == 0
    score > 0 ? "score-positive" : "score-negative"
  end

  def confirm_score_class(score, want, buttons)
    base = buttons ? "button " : ""
    return "#{base}score-neutral" if score != want || score == 0
    base + score_class(score)
  end

  def rating_collection
    # Post::Ratings.map.transform_keys(&:titleize).to_a
    [
      %w[Safe s],
      %w[Questionable q],
      %w[Explicit e],
    ]
  end

  def generate_report_signature(purpose:, **values)
    Reports.generate_body_signature(purpose: purpose, ip_address: request.remote_ip, **values)
  end

  def view_count_js(post)
    sig = generate_report_signature(purpose: "view", post_id: post.id)
    render(partial: "posts/partials/common/report_js", locals: { sig: sig, url: "/views" })
  end

  def missed_post_search_count_js(tags, page)
    sig = generate_report_signature(purpose: "missed-search", tags: tags, page: page)
    render(partial: "posts/partials/common/report_js", locals: { sig: sig, url: "/searches/missed" })
  end

  def post_search_count_js(tags, page)
    sig = generate_report_signature(purpose: "search", tags: tags, page: page)
    render(partial: "posts/partials/common/report_js", locals: { sig: sig, url: "/searches" })
  end

  def post_ribbons(post, user = CurrentUser.user)
    tag.div(class: "ribbons") do
      safe_join([if post.parent_id.present?
                   if post.has_visible_children?(user)
                     tag.div(class: "ribbon left has-parent has-children", title: "Has Parent\nHas Children") do
                       tag.span
                     end
                   else
                     tag.div(class: "ribbon left has-parent", title: "Has Parent") do
                       tag.span
                     end
                   end
                 elsif post.has_visible_children?(user)
                   tag.div(class: "ribbon left has-children", title: "Has Children") do
                     tag.span
                   end
                 end,
                 if post.is_flagged?
                   if post.is_pending?
                     tag.div(class: "ribbon right is-flagged is-pending", title: "Flagged\nPending") do
                       tag.span
                     end
                   else
                     tag.div(class: "ribbon right is-flagged", title: "Flagged") do
                       tag.span
                     end
                   end
                 elsif post.is_pending?
                   tag.div(class: "ribbon right is-pending", title: "Pending") do
                     tag.span
                   end
                 end,])
    end
  end

  def post_vote_buttons(post, user = CurrentUser.user)
    tag.div(id: "vote-buttons") do
      safe_join([
        tag.button("", class: "button vote-button vote score-neutral", disabled: post.is_vote_locked?(user), data: { action: "up" }) do
          tag.span(class: "post-vote-up-#{post.id} score-#{post.is_voted_up?(user) ? 'positive' : 'neutral'}")
        end,
        tag.button("", class: "button vote-button vote score-neutral", disabled: post.is_vote_locked?(user), data: { action: "down" }) do
          tag.span(class: "post-vote-down-#{post.id} score-#{post.is_voted_down?(user) ? 'negative' : 'neutral'}")
        end,
        tag.button("", class: "button vote-button fav score-neutral", data: { action: "fav", state: post.is_favorited?(user) }) do
          tag.span(class: "post-favorite-#{post.id} score-neutral#{' is-favorited' if post.is_favorited?(user)}")
        end,
      ])
    end
  end
end

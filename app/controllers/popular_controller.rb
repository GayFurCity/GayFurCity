# frozen_string_literal: true

class PopularController < ApplicationController
  respond_to(:html, :json)

  def index
  end

  def uploads
    @date, @scale, @min_date, @max_date = parse_date(params)
    @post_set = PostSets::Popular::Uploads.new(@date, @scale, @min_date, @max_date, limit: limit, current_user: CurrentUser.user)
    @posts = @post_set.posts
    respond_with(@posts)
  rescue ArgumentError => e
    render_expected_error(422, e)
  end

  def views
    @date, @scale, @min_date, @max_date = parse_date(params, scales: %w[day])
    @post_set = PostSets::Popular::Views.new(@date, limit: limit, current_user: CurrentUser.user)
    @posts = @post_set.posts
    @ranking = @post_set.ranking.to_h { |r| [r["post"], r["count"]] }
    respond_with(@posts)
  rescue ArgumentError => e
    render_expected_error(422, e)
  end

  def top_views
    @post_set = PostSets::Popular::TopViews.new(limit: limit, current_user: CurrentUser.user)
    @ranking = @post_set.ranking.to_h { |r| [r["post"], r["count"]] }
    @posts = @post_set.posts
    @stats = Reports.get_stats
    respond_with(@posts)
  end

  def searches
    @date, @scale, @min_date, @max_date = parse_date(params, scales: %w[day])
    @ranking = Reports.get_post_searches_rank(@date).first(limit)
    @tags = Tag.find_by_name_list(@ranking.map(&:first))
    @nav = NavLinks.new(@date, "searches_popular_index_path", "top_searches_popular_index_path", helper: view_context, routes: view_context)
    respond_with(@ranking, &format_json(@ranking))
  rescue ArgumentError => e
    render_expected_error(422, e)
  end

  def top_searches
    @ranking = Reports.get_top_post_searches.first(limit)
    @tags = Tag.find_by_name_list(@ranking.map(&:first))
    @stats = Reports.get_stats
    respond_with(@ranking, &format_json(@ranking))
  end

  def missed_searches
    @date, @scale, @min_date, @max_date = parse_date(params, scales: %w[day])
    @ranking = Reports.get_missed_searches_rank(@date).first(limit)
    @nav = NavLinks.new(@date, "missed_searches_popular_index_path", "top_missed_searches_popular_index_path", helper: view_context, routes: view_context)
    respond_with(@ranking, &format_json(@ranking))
  rescue ArgumentError => e
    render_expected_error(422, e)
  end

  def top_missed_searches
    @ranking = Reports.get_top_missed_searches.first(limit)
    @stats = Reports.get_stats
    respond_with(@ranking, &format_json(@ranking))
  end

  def followed_tags
    @tags = Tag.order(follower_count: :desc, name: :asc).where.gt(follower_count: 0).paginate(params[:page], limit: limit)
    respond_with(@tags)
  end

  private

  def parse_date(params, scales: %w[day week month])
    date = params[:date].present? ? Date.parse(params[:date]) : Time.zone.now
    scale = params[:scale].in?(scales) ? params[:scale] : "day"
    min_date = date.send("beginning_of_#{scale}")
    max_date = date.send("next_#{scale}").send("beginning_of_#{scale}")

    [date, scale, min_date, max_date]
  end

  def popular_posts(min_date, max_date)
    Post.where(created_at: min_date..max_date).tag_match_current("order:score")
  end

  def limit(default: 100, min: 1, max: default)
    params.fetch(:limit, default).to_i.clamp(min..max)
  end

  # used for routes that don't have a post set
  class NavLinks
    attr_reader(:date, :path, :top_path, :h, :r)

    def initialize(date, path, top_path, helper: nil, routes: nil)
      @date = date
      @path = path
      @top_path = top_path
      @h = helper || Helpers
      @r = routes || Routes
    end

    def next_date
      date + 1.day
    end

    def prev_date
      date - 1.day
    end

    def build
      h.tag.p(id: "popular-nav-links") do
        h.safe_join([
          h.tag.span(class: "period") do
            h.safe_join([
              h.link_to("«prev", r.public_send(path, date: prev_date.strftime("%Y-%m-%d")), id: "paginator-prev", rel: "prev", data: { shortcut: "a left" }),
              h.link_to("Day", r.public_send(path, date: date.strftime("%Y-%m-%d")), class: "desc"),
              h.link_to("next»", r.public_send(path, date: next_date.strftime("%Y-%m-%d")), id: "paginator-next", rel: "next", data: { shortcut: "d right" }),
            ], "\n")
          end,
          h.tag.span(class: "period") do
            h.link_to("All Time", r.public_send(top_path))
          end,
        ], "\n")
      end
    end
  end
end

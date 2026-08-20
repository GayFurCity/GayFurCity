# frozen_string_literal: true

class PostsDecorator < ApplicationDecorator
  def self.collection_decorator_class
    PaginatedDecorator
  end

  alias post object

  delegate_all

  def preview_class(options, user: CurrentUser.user)
    klass = ["post-preview"]
    klass << "post-status-pending" if post.is_pending?
    klass << "post-status-flagged" if post.is_flagged?
    klass << "post-status-deleted" if post.is_deleted?
    klass << "post-status-has-parent" if post.parent_id
    klass << "post-status-has-children" if post.has_visible_children?(user)
    klass << "post-rating-safe" if post.rating == "s"
    klass << "post-rating-questionable" if post.rating == "q"
    klass << "post-rating-explicit" if post.rating == "e"
    klass << "blacklistable" unless options[:no_blacklist]
    klass
  end

  def data_attributes(user: CurrentUser.user)
    { data: post.thumbnail_attributes(user) }
  end

  def cropped_url(options, user: CurrentUser.user)
    cropped_url = if Config.instance.enable_image_cropping? && options[:show_cropped] && post.has_crop? && !user.disable_cropped_thumbnails?
                    post.crop_file_url(user)
                  else
                    post.preview_file_url(user)
                  end

    cropped_url = Config.instance.deleted_preview_url if post.deleteblocked?(user)
    cropped_url
  end

  def score_class(score)
    return "score-neutral" if score == 0
    score > 0 ? "score-positive" : "score-negative"
  end

  def preview_html(options = {})
    return "" if post.nil?

    if !options[:show_deleted] && post.is_deleted? && options[:tags] !~ /(?:status:(?:all|any|deleted|modqueue|appealed))|(?:deletedby:)|(?:delreason:)/i
      return ""
    end
    user = options.delete(:user) || CurrentUser.user

    if post.loginblocked?(user) || post.safeblocked?(user)
      return ""
    end

    article_attrs = {
      id:    "post_#{post.id}",
      class: preview_class(options, user: user).join(" "),
    }.merge(data_attributes(user: user))

    link_target = options[:link_target] || post

    link_params = {}
    if options[:tags].present?
      link_params["q"] = options[:tags]
    end
    if options[:pool_id]
      link_params["pool_id"] = options[:pool_id]
    end
    if options[:post_set_id]
      link_params["post_set_id"] = options[:post_set_id]
    end

    tooltip = "Rating: #{post.rating}\nID: #{post.id}\nDate: #{post.created_at}\nStatus: #{post.status}\nScore: #{post.score}"
    tooltip += "\nUploader: #{post.uploader_name}" if user.is_staff? || user.show_post_uploader?
    if user.is_staff? && (post.is_flagged? || post.is_deleted?)
      flag = post.flags.order(id: :desc).first
      tooltip += "\nFlag Reason: #{flag&.reason}" if post.is_flagged?
      tooltip += "\nDel Reason: #{flag&.reason}" if post.is_deleted?
    end
    tooltip += "\n\n#{post.tag_string}"

    cropped_url = if Config.instance.enable_image_cropping? && options[:show_cropped] && post.has_crop? && !user.disable_cropped_thumbnails?
                    post.crop_file_url(user)
                  elsif post.has_preview?
                    post.preview_file_url(user)
                  else
                    post.file_url(user)
                  end

    cropped_url = Config.instance.deleted_preview_url if post.deleteblocked?(user)
    preview_url = if post.deleteblocked?(user)
                    Config.instance.deleted_preview_url
                  elsif post.has_preview?
                    post.preview_file_url(user)
                  else
                    post.file_url(user)
                  end

    alt_text = post.tag_string

    has_cropped = post.has_crop?

    pool = options[:pool]

    similarity = options[:similarity]&.round

    size = options[:size] ? post.file_size : nil

    img_contents = link_to(r.polymorphic_path(link_target, link_params)) do
      tag.picture do
        safe_join([
          tag.source(media: "(max-width: 800px)", srcset: cropped_url),
          tag.source(media: "(min-width: 800px)", srcset: preview_url),
          tag.img(class: "has-cropped-#{has_cropped}", src: preview_url, title: tooltip, alt: alt_text),
        ])
      end
    end
    desc_contents = if options[:stats] || pool || similarity || size
                      tag.div(class: "desc") do
                        h.post_stats_section(post) if options[:stats]
                      end
                    else
                      ""
                    end

    ribbons = self.ribbons
    vote_buttons = self.vote_buttons
    tag.article(**article_attrs) do
      img_contents + desc_contents + ribbons + vote_buttons
    end
  end

  def ribbons
    h.post_ribbons(post)
  end

  def vote_buttons
    h.post_vote_buttons(post)
  end
end

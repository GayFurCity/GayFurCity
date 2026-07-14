# frozen_string_literal: true

module ApplicationHelper
  def disable_mobile_mode?
    if CurrentUser.user.present? && CurrentUser.user.is_member?
      return CurrentUser.disable_responsive_mode?
    end
    cookies[:nmm].present?
  end

  def diff_list_html(new, old, latest)
    diff = SetDiff.new(new, old, latest)
    render("diff_list", diff: diff)
  end

  def nav_link_to(text, url, **options)
    klass = options.delete(:class)

    if nav_link_match(params[:controller], url)
      klass = "#{klass} current"
    end

    li_link_to_id(text, url, id_prefix: "nav-", class: klass, **options)
  end

  def subnav_link_to(text, url, **)
    li_link_to_id(text, url, id_prefix: "subnav-", **)
  end

  def li_link_to(text, url, li_options: {}, **options)
    klass = options.delete(:class)
    tag.li(link_to(text, url, **options), class: klass, **li_options)
  end

  def li_link_to_id(text, url, id_prefix: "", li_options: {}, **)
    id = id_prefix + text.downcase.gsub(/[^a-z ]/, "").parameterize
    li_link_to(text, url, li_options: { **li_options, id: id }, **, id: "#{id}-link")
  end

  def dtext_ragel(text, **)
    parsed = DTextHelper.parse(text, **)
    return raw("") if parsed.nil? # rubocop:disable Rails/OutputSafety
    deferred_post_ids.merge(parsed[:post_ids]) if parsed[:post_ids].present?
    raw(parsed[:dtext]) # rubocop:disable Rails/OutputSafety
  rescue DText::Error
    raw("") # rubocop:disable Rails/OutputSafety
  end

  def bulk_dtext_ragel(texts, **)
    parsed = DTextHelper.bulk_parse(texts, **)
    return {} if parsed.empty?
    parsed.to_h do |text, hash|
      deferred_post_ids.merge(hash[:post_ids]) if hash[:post_ids].present?
      [text, raw(hash[:dtext])] # rubocop:disable Rails/OutputSafety
    end
  rescue DText::Error
    {}
  end

  def format_text(text, **options)
    # preserve the current inline behaviour
    if options[:inline]
      dtext_ragel(text, **options)
    else
      tag.div(dtext_ragel(text, **options), class: "styled-dtext")
    end
  end

  def bulk_format_text(texts, **options)
    if options[:inline]
      texts.index_with { |text| dtext_ragel(text, **options) }
    else
      parsed = bulk_dtext_ragel(texts, **options)
      parsed.transform_values do |dtext|
        tag.div(dtext, class: "styled-dtext")
      end
    end
  end

  def custom_form_for(object, *args, &)
    options = args.extract_options!
    simple_form_for(object, *(args << options.merge(builder: CustomFormBuilder)), &)
  end

  def error_messages_for(instance_name)
    instance = instance_variable_get("@#{instance_name}")

    if instance&.errors&.any?
      tag.div(safe_join([tag.b("Error"), ": ", instance.send(:errors).full_messages.join(", ")]), class: "error-messages ui-state-error ui-corner-all")
    else
      ""
    end
  end

  def time_tag(content, time)
    datetime = time.strftime("%Y-%m-%dT%H:%M%:z")
    tag.time(content || datetime, datetime: datetime, title: time.to_fs)
  end

  def time_ago_in_words_tagged(time, compact: false)
    if time.nil?
      tag.em(tag.time("unknown"))
    elsif time.past?
      text = "#{time_ago_in_words(time)} ago"
      text = text.gsub(/almost|about|over/, "") if compact
      time_tag(text, time)
    else
      time_tag("in #{distance_of_time_in_words(Time.now, time)}", time)
    end
  end

  def compact_time(time)
    time_tag(time.strftime("%Y-%m-%d %H:%M"), time)
  end

  def external_link_to(url, truncate: nil, strip_scheme: false, link_options: {})
    text = url
    text = text.gsub(%r{\Ahttps?://}i, "") if strip_scheme
    text = text.truncate(truncate) if truncate

    if url =~ %r{\Ahttps?://}i
      link_to(text, url, { rel: :nofollow }.merge(link_options))
    else
      url
    end
  end

  def link_to_ip(ip)
    return "(none)" unless ip
    banned = IpBan.is_banned?(ip)
    link_to(ip, moderator_ip_addrs_path(search: { ip_addr: ip }), class: "ip-addr #{'is-banned' if banned}")
  end

  def link_to_wiki(text, title = text, classes: nil, **)
    link_to(text, wiki_page_path(title), class: "wiki-link #{classes}", **)
  end

  def link_to_wikis(*wiki_titles, **)
    links = wiki_titles.map do |title|
      link_to_wiki(title.tr("_", " "), title)
    end

    to_sentence(links, **)
  end

  def link_to_user(user, include_activation: false)
    return "anonymous" if user.blank?

    user_class = user.level_css_class
    user_class += " user-post-approver" if user.can_approve_posts?
    user_class += " user-unrestricted-uploads" if user.unrestricted_uploads?
    user_class += " user-banned" if user.is_banned?
    user_class += " with-style" if CurrentUser.user.style_usernames?
    html = link_to(user.pretty_name, user_path(user), class: user_class, rel: "nofollow")
    html << " (Unactivated)" if include_activation && !user.is_verified?
    html
  end

  def table_for(...)
    table = TableBuilder.new(...)
    render(partial: "table_builder/table", locals: { table: table })
  end

  def body_attributes(user = CurrentUser.user)
    attributes = %i[id name level level_string can_approve_posts? unrestricted_uploads? per_page]
    attributes += User::Roles.map { |role| :"is_#{role}?" }

    controller_param = params[:controller].parameterize.dasherize
    action_param = params[:action].parameterize.dasherize

    {
      lang:  "en",
      class: "c-#{controller_param} a-#{action_param} #{'resp' unless disable_mobile_mode?}",
      data:  {
        controller: controller_param,
        action:     action_param,
        **data_attributes_for(user, attributes, prefix: "user"),
      },
    }
  end

  def data_attributes_for(record, attributes = ApiMethods.policy_for(CurrentUser.user, record).html_data_attributes, prefix: "data")
    attributes.flat_map do |attr|
      # If we have a hash, we assume this hash is a key-value of (relation, attributes)
      # [:is_read?, { category: %i[id name] }]
      if attr.is_a?(Hash)
        attr.flat_map do |key, sub_attrs|
          data_attributes_for(record.send(key), sub_attrs, prefix: "#{prefix}-#{key}").to_a
        end
      else
        name = attr.to_s.dasherize.delete("?").gsub("apionly_", "")
        value = record.send(attr)
        if value.is_a?(ApplicationRecord)
          data_attributes_for(value, prefix: "#{prefix}-#{name}").to_a
        else
          [[:"#{prefix}-#{name}", value]]
        end
      end
    end.to_h
  end

  def user_avatar(user)
    return "" if user.nil?
    post_id = user.avatar_id
    return "" unless post_id
    deferred_post_ids.add(post_id)
    tag.div(class: "post-thumb placeholder", id: "tp-#{post_id}", data: { id: post_id }) do
      tag.img(class: "thumb-img placeholder", src: "/images/thumb-preview.png", height: 150, width: 150)
    end
  end

  def unread_dmails(user)
    if user.has_mail?
      "(#{user.unread_dmail_count})"
    else
      ""
    end
  end

  def unread_notifications(user)
    if user.has_unread_notifications?
      "(#{user.unread_notification_count})"
    else
      ""
    end
  end

  def link_to_latest(id)
    return "" unless id
    subnav_link_to("Latest", params.permit!.merge(page: "b#{id + 1}"))
  end

  def latest_link(records, raw: false, separator: !raw)
    return unless CurrentUser.user.is_moderator?
    return if params[:action] != "index" || records.blank?
    link = link_to_latest(records.first.id)
    if raw
      link
    else
      content_for(:secondary_links) do
        safe_join([
          ("| " if separator),
          link,
        ].compact)
      end
    end
  end

  protected

  def nav_link_match(controller, url)
    # Static routes must match completely
    return url == request.path if controller == "static"

    url =~ case controller
           when "sessions", "users", "users/login_reminders", "users/password_resets", "admin/users", "dmails"
             %r{^/(session|users)}

           when "post_sets"
             %r{^/post_sets}

           when "comments"
             %r{^/comments}

           when "notes", "notes/versions"
             %r{^/notes}

           when "posts", "uploads", "posts/versions", "popular", "favorites"
             %r{^/posts}

           when "artists", "artist_versions"
             %r{^/artist}

           when "tags", "meta_searches", "tags/aliases", "tags/implications", "tags/related"
             %r{^/tags}

           when "pools", "pools/versions"
             %r{^/pools}

           when "moderator/dashboards"
             %r{^/moderator}

           when "wiki_pages", "wiki_pages/versions"
             %r{^/wiki_pages}

           when "forums", "forums/topics", "forums/posts"
             %r{^/forums}

           when "help"
             %r{^/help}

           # If there is no match activate the site map only
           else
             /^#{site_map_path}/
           end
  end

  def page?(controller, action = "")
    params[:controller].downcase.to_s == controller.downcase.to_s && (action.blank? || params[:action].downcase.to_s == action.downcase.to_s)
  end
end

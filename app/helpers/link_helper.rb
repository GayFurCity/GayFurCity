# frozen_string_literal: true

module LinkHelper
  def decorated_link_to(text, path, **)
    link_to(path, class: "decorated", **) do
      favicon_for_link(path) + text
    end
  end

  def favicon_for_link(path)
    hostname = hostname_for_link(path)
    if hostname
      tag.img(
        class: "link-decoration",
        # links to this site use its own icon
        src:   hostname == site_hostname ? SiteAsset.file_url("favicon-32x32.png") : DomainIcon.lookup.dig(hostname, "url"),
        data:  {
          hostname: hostname,
        },
      )
    else
      tag.i(
        class: "fa-solid fa-globe link-decoration",
        data:  { hostname: "none" },
      )
    end
  end

  # The domain whose icon is used for a link, checking parent domains too (i.imgur.com uses imgur.com)
  def hostname_for_link(path)
    begin
      uri = Addressable::URI.parse(path)
    rescue Addressable::URI::InvalidURIError
      return nil
    end
    return nil unless uri.host

    labels = DomainIcon.normalize_domain(uri.host).split(".")
    (0..(labels.size - 2)).each do |i|
      hostname = labels[i..].join(".")
      return hostname if hostname == site_hostname
      domain = DomainIcon.lookup.dig(hostname, "domain")
      return domain if domain
    end
    nil
  end

  def site_hostname
    GayFurCity.config.domain.sub(/:\d+\z/, "").delete_prefix("www.")
  end
end

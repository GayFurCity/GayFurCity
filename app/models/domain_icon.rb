# frozen_string_literal: true

# The icons shown next to links, see LinkHelper#favicon_for_link. Aliases are other domains that share the icon,
# like image servers. Subdomains of a domain or alias use its icon too.
class DomainIcon < ApplicationRecord
  include(ReplacesMediaAsset)

  DEFAULTS_FILE = Rails.root.join("db/seeds/domain_icons.yml")
  DEFAULTS_DIR = Rails.root.join("db/seeds/domain_icons")
  DOMAIN_REGEX = /\A[a-z0-9-]+(\.[a-z0-9-]+)+\z/

  has_media_asset(:domain_icon_media_asset)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  attr_reader(:direct_url) # required for the media asset shared code

  array_attribute(:aliases, parse: /[^\s,]+/, join_character: " ")

  normalizes(:domain, with: ->(domain) { normalize_domain(domain) })
  normalizes(:aliases, with: ->(aliases) { aliases.map { |domain| normalize_domain(domain) }.compact_blank.uniq })

  validates(:domain, presence: true, uniqueness: true, format: { with: DOMAIN_REGEX })
  validates(:file, presence: true, on: :create)
  validate(:validate_aliases)

  # has to run before the file is processed
  before_validation(:prepare_media_asset, prepend: true)
  after_create { self.file = nil }
  before_update { replace_media_asset(:domain_icon_media_asset) }
  after_destroy { domain_icon_media_asset.destroy }
  after_commit do
    Cache.delete("domain_icons")
    RequestStore.store.delete(:domain_icons)
  end

  def self.normalize_domain(domain)
    domain.to_s.strip.downcase.delete_prefix("www.")
  end

  # { domain or alias => { "domain" => domain, "url" => icon url } }
  def self.lookup
    RequestStore.store[:domain_icons] ||= Cache.fetch("domain_icons", expires_in: 1.hour) do
      includes(:domain_icon_media_asset).each_with_object({}) do |icon, hash|
        next unless icon.domain_icon_media_asset.active?
        entry = { "domain" => icon.domain, "url" => icon.file_url(user: nil) }
        [icon.domain, *icon.aliases].each { |domain| hash[domain] = entry }
      end
    end
  end

  # Creates any missing default icons
  def self.create_defaults!(user = User.system)
    YAML.load_file(DEFAULTS_FILE).each do |domain, aliases|
      next if exists?(domain: domain)
      File.open(DEFAULTS_DIR.join("#{domain}.png")) do |file|
        create!(domain: domain, aliases: aliases, creator: user, creator_ip_addr: "127.0.0.1", file: file)
      end
    end
  end

  def prepare_media_asset
    return unless domain_icon_media_asset&.new_record?
    domain_icon_media_asset.creator ||= creator
  end

  def validate_aliases
    errors.add(:aliases, "can't include the domain") if aliases.include?(domain)
    aliases.each do |domain|
      errors.add(:aliases, "#{domain} is not a valid domain") unless domain.match?(DOMAIN_REGEX)
    end
    others = DomainIcon.where.not(id: id)
    taken = others.where(domain: [domain, *aliases]).or(others.where("aliases && ARRAY[?]::varchar[]", [domain, *aliases])).pluck(:domain)
    errors.add(:base, "#{[domain, *aliases].join(', ')} overlaps with the icon for #{taken.to_sentence}") if taken.any?
  end

  module SearchMethods
    def query_dsl
      super
        .field(:domain, ilike: true)
        .custom(:domain_matches, ->(q, value) { q.where(domain: normalize_domain(value)).or(q.where("? = ANY(aliases)", normalize_domain(value))) })
        .association(:creator)
        .association(:updater)
    end

    def apply_order(params)
      order_with({
        domain: { "domain_icons.domain": :asc },
      }, params[:order])
    end
  end

  extend(SearchMethods)

  modactions(:domain_icon)
    .add(:create, :creator, on: :create) { { domain: domain } }
    .add(:update, :updater, on: :update) { { domain: domain } }
    .add(:delete, :destroyer, on: :destroy) { { domain: domain } }

  def self.available_includes
    %i[creator updater]
  end
end

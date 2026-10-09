# frozen_string_literal: true

# Images the site itself uses, like its icon. Each slot is a single upload that gets converted into every
# size the site needs. Every slot is created from its default file on setup (see .create_defaults!).
class SiteAsset < ApplicationRecord
  # default is relative to public/, and is served as-is if the slot is ever missing
  # files maps public file names to the variant served for them
  # size_config is the admin config holding the slot's min and max size
  Slot = Struct.new(:name, :title, :hint, :default, :size_config, :png_sizes, :ico_sizes, :files, keyword_init: true) do
    def default_path
      "/#{default}"
    end

    def default_file
      Rails.public_path.join(default)
    end

    def size
      AdminConfig.get(size_config)
    end
  end

  SLOTS = [
    Slot.new(
      name:        "icon",
      title:       "Icon",
      hint:        "Used for the favicon, app icons and site logo.",
      default:     "images/main-icon.png",
      size_config: :site_icon_size,
      png_sizes:   [16, 32, 36, 48, 57, 60, 70, 72, 76, 96, 114, 120, 144, 150, 152, 180, 192, 310, 512],
      ico_sizes:   [16, 32, 48],
      files:       {
        "favicon.ico"                => "ico",
        "main-icon.png"              => "png_512",
        "apple-icon.png"             => "png_180",
        "apple-icon-precomposed.png" => "png_180",
        **[16, 32, 96].to_h { |size| ["favicon-#{size}x#{size}.png", "png_#{size}"] },
        **[57, 60, 72, 76, 114, 120, 144, 152, 180].to_h { |size| ["apple-icon-#{size}x#{size}.png", "png_#{size}"] },
        **[36, 48, 72, 96, 144, 192].to_h { |size| ["android-icon-#{size}x#{size}.png", "png_#{size}"] },
        **[70, 144, 150, 310].to_h { |size| ["ms-icon-#{size}x#{size}.png", "png_#{size}"] },
      },
    ),
  ].index_by(&:name).freeze

  has_media_asset(:site_media_asset)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  attr_reader(:direct_url) # required for the media asset shared code

  validates(:name, inclusion: { in: SLOTS.keys }, uniqueness: true)
  validates(:file, presence: true, on: :create)

  # has to run before the file is processed
  before_validation(:prepare_media_asset, prepend: true)
  after_create { self.file = nil }
  before_update(:update_file)
  after_destroy { site_media_asset.destroy }
  after_commit { Cache.delete("site_asset_urls") }

  def self.slot(name)
    SLOTS.fetch(name.to_s)
  end

  def self.slot_for_file(file)
    SLOTS.values.find { |slot| slot.files.key?(file) }
  end

  # the uploaded version of a public file, or the bundled default
  def self.file_url(file)
    slot = slot_for_file(file)
    raise(ArgumentError, "unknown site asset file: #{file}") if slot.nil?
    url_for(slot.name, slot.files[file]) || slot.default_path
  end

  # Creates any missing slots from their default file
  def self.create_defaults!(user = User.system)
    SLOTS.each_value do |slot|
      next if exists?(name: slot.name)
      File.open(slot.default_file) { |file| create!(name: slot.name, creator: user, creator_ip_addr: "127.0.0.1", file: file) }
    end
  end

  # { name => { variant => url } } for every uploaded slot
  def self.urls
    Cache.fetch("site_asset_urls", expires_in: 1.hour) do
      includes(:site_media_asset).select { |asset| asset.site_media_asset.active? }.to_h { |asset| [asset.name, asset.variant_urls] }
    end
  end

  # nil when the slot hasn't been uploaded
  def self.url_for(name, variant)
    urls.dig(name.to_s, variant.to_s)
  end

  def slot
    SiteAsset.slot(name)
  end

  def prepare_media_asset
    return unless site_media_asset&.new_record?
    site_media_asset.name ||= name
    site_media_asset.creator ||= creator
  end

  def variant_urls
    site_media_asset.generated_variant_list.to_h { |variant| [variant.type.to_s, variant.file_url(user: nil)] }
  end

  def update_file
    return if file.blank?
    file = self.file
    self.file = nil
    old_asset = site_media_asset
    new_asset = SiteMediaAsset.new(name: name, creator: updater, checksum: MediaAsset.md5(file.path))
    new_asset.append_all!(file, save: false)
    if new_asset.valid? && new_asset.active?
      # saved before being assigned, otherwise it saves this record again through the inverse association
      new_asset.save!
      self.site_media_asset = new_asset
      old_asset.updater = updater
      old_asset.delete_all_files
      old_asset.update_columns(status: "replaced")
    else
      errors.merge!(new_asset.errors)
      errors.add(:file, new_asset.status_message) if new_asset.status_message.present? && errors.empty?
      throw(:abort)
    end
  end

  modactions(:site_asset)
    .add(:create, :creator, on: :create) { { name: name } }
    .add(:update, :updater, on: :update) { { name: name } }
    .add(:delete, :destroyer, on: :destroy) { { name: name } }

  def self.available_includes
    %i[creator updater]
  end
end

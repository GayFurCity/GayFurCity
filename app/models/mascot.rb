# frozen_string_literal: true

class Mascot < ApplicationRecord
  has_media_asset(:mascot_media_asset)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  array_attribute(:available_on, parse: /[^,]+/, join_character: ",")
  attr_reader(:direct_url) # required for the media asset shared code

  validates(:display_name, uniqueness: { case_sensitive: false })
  validates(:display_name, :background_color, :artist_url, :artist_name, presence: true)
  validates(:artist_url, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }, length: { maximum: 1_000 })
  validates(:display_name, :artist_name, length: { maximum: 100 })
  validates(:file, presence: true, on: :create)
  validate(:file_is_not_duplicate, on: :update)

  after_create { self.file = nil }
  before_update(:update_file)
  after_destroy { mascot_media_asset.destroy }

  def file_is_not_duplicate
    return if file.blank?
    duplicates = MascotMediaAsset.duplicates_of(MediaAsset.md5(file.path))
    return if duplicates.empty?
    errors.add(:file, "is a duplicate of existing mascot(s): #{duplicates.includes(:mascot).map { |d| d.mascot.present? ? "mascot ##{d.mascot.id}" : "mascot media asset ##{d.id}" }.join(', ')}")
  end

  def update_file
    return if file.blank?
    file = self.file
    self.file = nil
    old_asset = mascot_media_asset
    new_asset = MascotMediaAsset.new(creator: updater, checksum: MediaAsset.md5(file.path))
    new_asset.append_all!(file, save: false)
    self.mascot_media_asset = new_asset
    if new_asset.valid?
      new_asset.save!
      old_asset.updater = updater
      old_asset.delete_all_files
      old_asset.update_columns(status: "replaced")
    else
      throw(:abort)
    end
  end

  def self.active_for_user(user)
    mascots = Cache.fetch("active_mascots", expires_in: 1.second) do
      query = Mascot.where(active: true).where("? = ANY(available_on)", AdminConfig.instance.app_name).with_assets
      mascots = query.map do |mascot|
        mascot.slice(:id, :background_color, :artist_url, :artist_name, :hide_anonymous).merge(background_url: mascot.file_url(user: user))
      end
      mascots.index_by { |mascot| mascot["id"] }
    end
    if user.nil? || user.is_anonymous?
      mascots.each_pair do |id, mascot|
        mascots.delete(id) if mascot[:hide_anonymous]
      end
    end
    mascots
  end

  def invalidate_cache
    Cache.delete("active_mascots")
  end

  def self.search(params, user)
    q = super
    q.order("lower(artist_name)")
  end

  modactions(:mascot)
    .add(:create, :creator, on: :create)
    .add(:update, :updater, on: :update)
    .add(:delete, :destroyer, on: :destroy)

  include(FileMethods)

  def apionly_file_url
    file_url(user: CurrentUser.user)
  end

  def self.available_includes
    %i[creator]
  end
end

# frozen_string_literal: true

class UploadWhitelist < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  before_save(:clean_pattern)
  after_save(:clear_cache)

  validates(:pattern, presence: true)
  validates(:pattern, uniqueness: true)
  validates(:pattern, format: { with: %r{\A[a-zA-Z0-9.%:_\-*/?&]+\z} })

  modactions(:upload_whitelist)
    .add(:create, :creator, on: :create) { { pattern: pattern, note: note, hidden: hidden } }
    .add(:update, :updater, on: :update) { { pattern: pattern, old_pattern: pattern_before_last_save, note: note, hidden: hidden } }
    .add(:delete, :destroyer, on: :destroy) { { pattern: pattern, note: note, hidden: hidden } }

  def clean_pattern
    self.pattern = pattern.downcase.tr("%", "*")
  end

  def clear_cache
    Cache.delete("upload_whitelist")
  end

  module SearchMethods
    def default_order
      order(:note)
    end

    def query_dsl
      super
        .field(:pattern, ilike: true)
        .field(:note, ilike: true)
        .association(:creator)
        .association(:updater)
    end

    def apply_order(params)
      order_with({
        pattern: { "upload_whitelists.pattern": :asc },
        note:    { "upload_whitelists.note": :asc },
      }, params[:order])
    end
  end

  def self.is_whitelisted?(url, user)
    if url.userinfo.present?
      return [false, "URLs with embedded credentials are not allowed"]
    end

    entries = Cache.fetch("upload_whitelist", expires_in: 6.hours) do
      all
    end

    if GayFurCity.config.bypass_upload_whitelist?(user)
      return [true, "bypassed"]
    end

    entries.each do |x|
      if File.fnmatch?(x.pattern, url, File::FNM_CASEFOLD)
        return [x.allowed, x.reason]
      end
    end
    [false, "#{url.host} not in whitelist"]
  end

  extend(SearchMethods)
end

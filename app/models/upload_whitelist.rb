# frozen_string_literal: true

class UploadWhitelist < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  before_save(:clean_pattern)
  after_create(:log_create)
  after_update(:log_update)
  after_destroy(:log_delete)
  after_save(:clear_cache)

  validates(:pattern, presence: true)
  validates(:pattern, uniqueness: true)
  validates(:pattern, format: { with: %r{\A[a-zA-Z0-9.%:_\-*/?&]+\z} })

  def clean_pattern
    self.pattern = pattern.downcase.tr("%", "*")
  end

  def clear_cache
    Cache.delete("upload_whitelist")
  end

  module LogMethods
    def log_create
      ModAction.log!(creator, :upload_whitelist_create, self, pattern: pattern, note: note, hidden: hidden)
    end

    def log_update
      ModAction.log!(updater, :upload_whitelist_update, self, pattern: pattern, note: note, old_pattern: pattern_before_last_save, hidden: hidden)
    end

    def log_delete
      ModAction.log!(destroyer, :upload_whitelist_delete, self, pattern: pattern, note: note, hidden: hidden)
    end
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

  include(LogMethods)
  extend(SearchMethods)
end

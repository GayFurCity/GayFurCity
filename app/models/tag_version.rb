# frozen_string_literal: true

class TagVersion < ApplicationRecord
  belongs_to_user(:updater, ip: true)
  belongs_to(:tag)

  module SearchMethods
    def query_dsl
      super
        .field(:tag_id)
        .field(:ip_addr, :updater_ip_addr)
        .custom(:tag_name, ->(q, v) { q.where(tag: Tag.find_by_normalized_name(v)) })
        .association(:updater)
        .association(:tag)
    end
  end

  extend(SearchMethods)

  def previous
    TagVersion.where(tag_id: tag_id).where.lt(created_at: created_at).order(created_at: :desc).first
  end

  def category_changed?
    previous && previous.category != category
  end

  def is_locked_changed?
    previous && previous.is_locked? != is_locked?
  end

  def is_deprecated_changed?
    previous && previous.is_deprecated? != is_deprecated?
  end

  def self.available_includes
    %i[tag updater]
  end
end

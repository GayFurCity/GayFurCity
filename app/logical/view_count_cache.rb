# frozen_string_literal: true

class ViewCountCache < ActiveSupport::CurrentAttributes
  attribute(:cache, default: {})
  attribute(:user, default: -> { User.anonymous })

  def add!(post_id, count, type)
    cache[:"view_count_#{type}_cache"] ||= {}
    cache[:"view_count_#{type}_cache"][post_id] = count
  end

  def add_all!(hash, type)
    cache[:"view_count_#{type}_cache"] ||= {}
    cache[:"view_count_#{type}_cache"].merge!(hash)
  end

  def get(post_id, type)
    value = cache.dig(:"view_count_#{type}_cache", post_id)
    return value if value.present?

    # Daily views should not be deduped as this can cause views to not show up
    value = Reports.get_post_views(post_id, date: type == :daily ? Time.now : nil, unique: type == :daily ? false : user.unique_views?)
    add!(post_id, value, type)
    value
  end
end

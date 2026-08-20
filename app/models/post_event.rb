# frozen_string_literal: true

class PostEvent < ApplicationRecord
  belongs_to_user(:creator, ip: true)
  belongs_to(:post)
  enum(:action, {
    deleted:                 0,
    undeleted:               1,
    approved:                2,
    unapproved:              3,
    flag_created:            4,
    flag_removed:            5,
    favorites_moved:         6,
    favorites_received:      7,
    rating_locked:           8,
    rating_unlocked:         9,
    status_locked:           10,
    status_unlocked:         11,
    note_locked:             12,
    note_unlocked:           13,
    replacement_accepted:    14,
    replacement_rejected:    15,
    replacement_promoted:    20,
    replacement_deleted:     16,
    expunged:                17,
    comment_disabled:        18,
    comment_enabled:         19,
    comment_locked:          21,
    comment_unlocked:        22,
    changed_bg_color:        23,
    changed_thumbnail_frame: 24,
    appeal_created:          25,
    appeal_accepted:         26,
    appeal_rejected:         27,
    copied_notes:            28,
    set_min_edit_level:      29,
    unlisted:                30,
    relisted:                31,
    in_progress_finished:    32,
    in_progress_forced:      33,
    replacement_transferred: 34,
  })

  MOD_ONLY_SEARCH_ACTIONS = [
    actions[:comment_locked],
    actions[:comment_unlocked],
    actions[:comment_disabled],
    actions[:comment_enabled],
  ].freeze

  EXTRA_DATA = %i[
    reason
    parent_id
    child_id
    source_post_id
    bg_color
    old_thumbnail_frame new_thumbnail_frame
    note_count
    post_appeal_id
    post_flag_id
    post_replacement_id old_md5 new_md5 md5 storage_id old_post new_post
    min_edit_level
  ].freeze

  store_accessor(:extra_data, *EXTRA_DATA)

  def self.search_options_for(user)
    options = actions.keys
    return options if user.is_moderator?
    options.reject { |action| MOD_ONLY_SEARCH_ACTIONS.any?(actions[action]) }
  end

  def self.add(...)
    TraceLogger.warn("PostEvent", "use PostEvent.add! instead of PostEvent.add", ignore: %r{/models/post_event\.rb})
    add!(...)
  end

  def self.add!(post_id, creator, action, data = {})
    create!(post_id: post_id, creator: creator, action: action.to_s, extra_data: data)
  end

  def is_creator_visible?(user)
    case action
    when "flag_created"
      user.can_view_flagger?(creator_id)
    else
      true
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:post_id)
        .custom(:action, method(:action_query).to_proc)
        .custom(:creator_id, method(:creator_id_query).to_proc)
        .custom(:creator_name, method(:creator_name_query).to_proc)
        .field(:ip_addr, :creator_ip_addr)
        # TODO: We need access control/blocks for associations
        # .association(:creator)
        .association(:post)
    end

    def action_query(q, value, user)
      value = value.to_s.split(",").map { |v| actions[v] }.compact
      restricted = value.select { |v| MOD_ONLY_SEARCH_ACTIONS.include?(v) }.map { |v| actions.key(v) }.compact
      raise(User::PrivilegeError, "#{restricted.join(', ')} cannot be used") if !user.is_moderator? && restricted.any?
      q.where(action: value)
    end

    def creator_id_query(q, value, user)
      value = value.to_s.split(",").map(&:to_i)
      return q.where(creator_id: value) if user.is_moderator?
      q.where.not(
        action:     actions[:flag_created],
        creator_id: value.reject { |user_id| user.can_view_flagger?(user_id) },
      ).where(creator_id: value)
    end

    def creator_name_query(q, value, user)
      id = User.name_to_id(value)
      creator_id_query(q, id.to_s, user)
    end
  end

  module ApiMethods
    def serializable_hash(options)
      hash = super
      # Rails 8.0+ may hand us a frozen options hash (e.g. reused internally for template lookup
      # caching when rendering through `respond_with`/`responders`), so work off our own copy.
      options = (options || {}).dup
      options[:user] ||= CurrentUser.user || User.anonymous
      hash[:creator_id] = nil unless is_creator_visible?(options[:user])
      hash
    end
  end

  include(ApiMethods)
  extend(SearchMethods)

  # rubocop:disable YiffSpace/CurrentOutsideOfRequests
  BLANK = { text: ->(_log) { "" }, json: [] }.freeze
  FORMATTERS = {
    deleted:                 {
      text: ->(log) { log.reason.to_s },
      json: %i[reason],
    },
    undeleted:               BLANK,
    approved:                BLANK,
    unapproved:              BLANK,
    flag_created:            {
      text: ->(log) { log.reason.to_s },
      json: %i[post_flag_id reason],
    },
    flag_removed:            {
      text: ->(_log) { "" },
      json: %i[post_flag_id],
    },
    favorites_moved:         {
      text: ->(log) { "Target: post ##{log.parent_id}" },
      json: %i[parent_id],
    },
    favorites_received:      {
      text: ->(log) { "From: post ##{log.child_id}" },
      json: %i[child_id],
    },
    rating_locked:           BLANK,
    rating_unlocked:         BLANK,
    status_locked:           BLANK,
    status_unlocked:         BLANK,
    note_locked:             BLANK,
    note_unlocked:           BLANK,
    replacement_accepted:    {
      text: ->(log) { "\"replacement ##{log.post_replacement_id}\":#{url.post_replacements_path(search: { id: log.post_replacement_id })}" },
      json: %i[post_replacement_id old_md5 new_md5],
    },
    replacement_rejected:    {
      text: ->(log) { "\"replacement ##{log.post_replacement_id}\":#{url.post_replacements_path(search: { id: log.post_replacement_id })}" },
      json: %i[post_replacement_id],
    },
    replacement_promoted:    {
      text: ->(log) { "Source: post ##{log.source_post_id}" },
      json: %i[post_replacement_id source_post_id],
    },
    replacement_deleted:     {
      text: ->(_log) { "" },
      json: ->(_log) do
        return %i[post_replacement_id] unless CurrentUser.user.is_admin?
        %i[post_replacement_id md5 storage_id]
      end,
    },
    replacement_transferred:       {
      text: ->(log) { "\"replacement ##{log.post_replacement_id}\":#{url.post_replacements_path(search: { id: log.post_replacement_id })} (post ##{log.old_post} -> post ##{log.new_post})" },
      json: %i[post_replacement_id old_post new_post],
    },
    expunged:                BLANK,
    comment_disabled:        BLANK,
    comment_enabled:         BLANK,
    comment_unlocked:        BLANK,
    changed_bg_color:        {
      text: ->(log) { "To: #{log.bg_color.present? ? "##{log.bg_color}" : 'None'}" },
      json: %i[bg_color],
    },
    changed_thumbnail_frame: {
      text: ->(log) { "#{log.old_thumbnail_frame || 'Default'} -> #{log.new_thumbnail_frame || 'Default'}" },
      json: %i[old_thumbnail_frame new_thumbnail_frame],
    },
    appeal_created:          {
      text: ->(log) { "\"appeal ##{log.post_appeal_id}\":#{url.post_appeals_path(search: { id: log.post_appeal_id })}" },
      json: %i[post_appeal_id],
    },
    appeal_accepted:         {
      text: ->(log) { "\"appeal ##{log.post_appeal_id}\":#{url.post_appeals_path(search: { id: log.post_appeal_id })}" },
      json: %i[post_appeal_id],
    },
    appeal_rejected:         {
      text: ->(log) { "\"appeal ##{log.post_appeal_id}\":#{url.post_appeals_path(search: { id: log.post_appeal_id })}" },
      json: %i[post_appeal_id],
    },
    copied_notes:            {
      text: ->(log) { "Copied #{log.note_count} #{'note'.pluralize(log.note_count)} from post ##{log.source_post_id}" },
      json: %i[source_post_id note_count],
    },
    set_min_edit_level:      {
      text: ->(log) { "To: [b]#{User::Levels.id_to_name(log.min_edit_level)}[/b]" },
      json: %i[min_edit_level],
    },
    unlisted:                BLANK,
    relisted:                BLANK,
    in_progress_finished:    BLANK,
    in_progress_forced:      BLANK,
  }.freeze

  def self.url
    Rails.application.routes.url_helpers
  end

  def format_unknown(log)
    CurrentUser.user.is_admin? ? "Unknown action #{log.action}: #{log.extra_data.inspect}" : "Unknown action #{log.action}"
  end

  def format_text
    FORMATTERS[action.to_sym]&.[](:text)&.call(self) || format_unknown(self)
  end

  def json_keys
    formatter = FORMATTERS[action.to_sym]&.[](:json)
    return CurrentUser.user.is_admin? ? values.keys : [] unless formatter
    formatter.is_a?(Proc) ? formatter.call(self) : formatter
  end

  def format_json
    keys = FORMATTERS[action.to_sym]&.[](:json)
    return CurrentUser.user.is_admin? ? values : {} if keys.nil?
    keys = keys.call(self) if keys.is_a?(Proc)
    keys.index_with(&method(:send))
  end

  KNOWN_ACTIONS = FORMATTERS.keys.freeze
  # rubocop:enable YiffSpace/CurrentOutsideOfRequests
  def self.available_includes
    %i[post]
  end
end

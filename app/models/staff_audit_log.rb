# frozen_string_literal: true

class StaffAuditLog < ApplicationRecord
  VALUES = %i[
    reason title
    target_id query post_ids
    new_level old_level
    new_user_id old_user_id
    staff_note_id body old_body
    ip_addr
    comment_id post_id forum_post_id vote voter_id
    destroyed_post_id
    duration
    params
    data
  ].freeze

  store_accessor(:values, *VALUES)
  belongs_to_user(:user, ip: true)

  def self.log(...)
    TraceLogger.warn("StaffAuditLog", "use StaffAuditLog.log! instead of StaffAuditLog.log", ignore: %r{/models/staff_audit_log\.rb})
    log!(...)
  end

  def self.log!(user, category, **details)
    create!(user: user, action: category.to_s, values: details)
  end

  def self.h
    Rails.application.routes.url_helpers
  end

  # rubocop:disable YiffSpace/CurrentOutsideOfRequests
  FORMATTERS = {
    force_name_change:          {
      text: ->(log) { "Forced a name change for #{link_to_user(log.target_id)}" },
      json: %i[target_id],
    },
    age_verified:               {
      text: ->(log) { "Marked #{link_to_user(log.target_id)} as age verified" },
      json: %i[target_id],
    },
    age_unverified:             {
      text: ->(log) { "Marked #{link_to_user(log.target_id)} as not age verified" },
      json: %i[target_id],
    },
    hide_pending_posts_for:     {
      text: ->(log) { "Hid pending posts for #{log.duration} #{'hour'.pluralize(duration)}#{" (#{duration / 24} days)" if log.duration >= 24}" },
      json: %i[duration],
    },
    lockdown:                   {
      text: ->(log) do
        text = "Updated lockdown"
        log.params.each do |k, v|
          text += "\nset #{k} to #{v}"
        end
        text
      end,
      json: %i[params],
    },
    lockdown_panic:             {
      text: ->(_log) { "Enabled lockdown panic" },
      json: %i[],
    },
    min_upload_level_change:    {
      text: ->(log) { "Changed the minimum upload level from [b]#{User::Levels.id_to_name(log.old_level)}[/b] to [b]#{User::Levels.id_to_name(log.new_level)}[/b]" },
      json: %i[new_level old_level],
    },
    post_owner_reassign:        {
      text: ->(log) { "Reassigned #{log.post_ids.length} #{'post'.pluralize(log.post_ids.length)} with query \"#{log.query}\" from \"#{User.id_to_name(log.old_user_id)}\":/users/#{log.old_user_id} to \"#{User.id_to_name(log.new_user_id)}\":/users/#{log.new_user_id}" },
      json: %i[query post_ids old_user_id new_user_id],
    },
    stuck_dnp:                  {
      text: ->(log) { "Removed dnp tags from #{log.post_ids.length} #{'post'.pluralize(log.post_ids.length)} with query \"#{log.query}\"" },
      json: %i[query post_ids],
    },
    user_title_change:          {
      text: ->(log) { "Set the title of #{link_to_user(log.target_id)} to \"#{log.title}\"" },
      json: %i[target_id title],
    },

    ### IP Ban ###
    ip_ban_create:              {
      text: ->(log) { "Created ip ban #{log.ip_addr}\nBan reason: #{log.reason}" },
      json: %i[ip_addr reason],
    },
    ip_ban_delete:              {
      text: ->(log) { "Deleted ip ban  #{log.ip_addr}\nBan reason: #{log.reason}" },
      json: %i[ip_addr reason],
    },

    ### Staff Notes ##
    staff_note_create:          {
      text: ->(log) do
        "Created \"staff note ##{log.staff_note_id}\":#{h.user_staff_notes_path(user_id: log.target_id, search: { id: log.staff_note_id })} for #{link_to_user(log.target_id)} with body: [section=Body]#{log.body}[/section]"
      end,
      json: %i[staff_note_id target_id body],
    },
    staff_note_update:          {
      text: ->(log) do
        "Updated \"staff note ##{log.staff_note_id}\":#{h.user_staff_notes_path(user_id: log.target_id, search: { id: log.staff_note_id })} for #{link_to_user(log.target_id)}\nChanged body: [section=Old]#{log.old_body}[/section]\n[section=New]#{log.body}[/section]"
      end,
      json: %i[staff_note_id target_id body old_body],
    },
    staff_note_delete:          {
      text: ->(log) do
        "Deleted \"staff note ##{log.staff_note_id}\":#{h.user_staff_notes_path(log.target_id, search: { id: log.staff_note_id })} for #{link_to_user(log.target_id)}"
      end,
      json: %i[staff_note_id target_id],
    },
    staff_note_undelete:        {
      text: ->(log) do
        "Undeleted \"staff note ##{log.staff_note_id}\":#{h.user_staff_notes_path(user_id: log.target_id, search: { id: log.staff_note_id })} for #{link_to_user(log.target_id)}"
      end,
      json: %i[staff_note_id target_id],
    },

    ### Comments ###
    comment_vote_delete:        {
      text: ->(log) { "Deleted #{['downvote', 'locked vote', 'upvote'][log.vote + 1]} on comment ##{log.comment_id} for user #{link_to_user(log.voter_id)}" },
      json: %i[vote comment_id voter_id],
    },
    comment_vote_lock:          {
      text: ->(log) { "Locked #{['downvote', 'locked vote', 'upvote'][log.vote + 1]} on comment ##{log.comment_id} for user #{link_to_user(log.voter_id)}" },
      json: %i[vote comment_id voter_id],
    },

    ### Posts ###
    post_vote_delete:           {
      text: ->(log) { "Deleted #{['downvote', 'locked vote', 'upvote'][log.vote + 1]} on post ##{log.post_id} for user #{link_to_user(log.voter_id)}" },
      json: %i[vote post_id voter_id],
    },
    post_vote_lock:             {
      text: ->(log) { "Locked #{['downvote', 'locked vote', 'upvote'][log.vote + 1]} on post ##{log.post_id} for user #{link_to_user(log.voter_id)}" },
      json: %i[vote post_id voter_id],
    },

    ### Forum Posts ###
    forum_post_vote_delete:     {
      text: ->(log) { "Deleted #{['downvote', 'meh vote', 'upvote'][log.vote + 1]} on forum ##{log.forum_post_id} for user #{link_to_user(log.voter_id)}" },
      json: %i[vote forum_post_id voter_id],
    },

    ### Destroyed Post Notifications ###
    enable_post_notifications:  {
      text: ->(log) { "Enabled re-upload notifications for \"destroyed post ##{log.post_id}\":#{h.admin_destroyed_post_path(id: log.post_id)}" },
      json: %i[destroyed_post_id post_id],
    },
    disable_post_notifications: {
      text: ->(log) { "Disabled re-upload notifications for \"destroyed post ##{log.post_id}\":#{h.admin_destroyed_post_path(id: log.post_id)}" },
      json: %i[destroyed_post_id post_id],
    },

    ### AdminConfig ###
    config_update:              {
      text: ->(log) { "Updated the config keys: #{log.data.keys.join(', ')}" },
      json: %i[data],
    },
  }.freeze
  ACTIONS = FORMATTERS.keys.freeze

  def self.link_to_user(id)
    "\"#{User.id_to_name(id)}\":/users/#{id}"
  end

  def format_unknown(log)
    CurrentUser.user.is_admin? ? "Unknown action #{log.action}: #{log.values.inspect}" : "Unknown action #{log.action}"
  end

  def format_text
    FORMATTERS[action.to_sym]&.[](:text)&.call(self) || format_unknown(self)
  end

  def json_keys
    FORMATTERS[action.to_sym]&.[](:json) || (CurrentUser.user.is_admin? ? values.keys : [])
  end

  def format_json
    FORMATTERS[action.to_sym]&.[](:json)&.index_with { |k| send(k) } || (CurrentUser.user.is_admin? ? values : {})
  end
  KNOWN_ACTIONS = FORMATTERS.keys.freeze
  # rubocop:enable YiffSpace/CurrentOutsideOfRequests

  module SearchMethods
    def query_dsl
      super
        .field(:action, multi: true)
        .association(:user)
    end
  end

  extend(SearchMethods)

  def self.available_includes
    %i[user]
  end
end

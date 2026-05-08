# frozen_string_literal: true

class ModAction < ApplicationRecord
  class InvalidCreatorError < StandardError; end
  belongs_to_user(:creator, ip: true)
  belongs_to(:subject, polymorphic: true, optional: true)
  cattr_accessor(:disable_logging, default: false)

  # make sure to update the openapi spec when changing the values, actions, or classes

  # inline results in rubocop aligning everything with :values
  VALUES = %i[
    user_id
    name
    total
    tag_name
    change_desc
    reason old_reason
    header old_header
    description old_description
    antecedent consequent
    query
    alias_desc
    implication_desc
    is_public
    added removed
    level old_level
    upload_limit old_upload_limit
    new_name old_name
    duration
    expires_at old_expires_at
    forum_category_id old_forum_category_id forum_category_name old_forum_category_name can_view old_can_view can_create old_can_create
    forum_topic_id forum_topic_title old_topic_id old_topic_title new_topic_id new_topic_title
    pool_name
    pattern old_pattern note hidden
    type old_type
    wiki_page wiki_page_title old_title wiki_page_id protection_level target_wiki_page_id target_wiki_page_title
    category_name old_category_name
    prompt old_prompt title
    artist_name
    post_id
  ].freeze

  store_accessor(:values, *VALUES)

  def self.log(...)
    TraceLogger.warn("ModAction", "use ModAction.log! instead of ModAction.log", ignore: %r{/models/mod_action\.rb})
    log!(...)
  end

  def self.log!(creator, action, subject, **details)
    if disable_logging
      Rails.logger.warn("ModAction: skipped logging for #{action} #{subject&.class&.name} #{details.inspect}")
      return
    end
    raise(InvalidCreatorError, "Invalid creator: #{creator.inspect}") if creator.nil? || !(creator.is_a?(User) || (creator.is_a?(UserResolvable) && creator.user.is_a?(User)))
    create!(creator: creator, action: action.to_s, subject: subject, values: details)
  end

  # rubocop:disable YiffSpace/CurrentUserOutsideOfRequests
  FORMATTERS = {
    ### Artist ###
    artist_lock:                                {
      text: ->(mod, _user) { "Locked artist ##{mod.subject_id}" },
      json: %i[],
    },
    artist_rename:                              {
      text: ->(mod, _user) { "Renamed artist ##{mod.subject_id} (\"#{mod.old_name}\":#{url.show_or_new_artists_path(name: mod.old_name)} -> \"#{mod.new_name}\":#{url.show_or_new_artists_path(name: mod.new_name)})" },
      json: %i[old_name new_name],
    },
    artist_unlock:                              {
      text: ->(mod, _user) { "Unlocked artist ##{mod.subject_id}" },
      json: %i[],
    },
    artist_user_link:                           {
      text: ->(mod, user) { "Linked #{user} to artist ##{mod.subject_id}" },
      json: %i[user_id],
    },
    artist_user_unlink:                         {
      text: ->(mod, user) { "Unlinked #{user} from artist ##{mod.subject_id}" },
      json: %i[user_id],
    },

    ### Ban ###
    ban_create:                                 {
      text: ->(mod, user) do
        if mod.duration.is_a?(Numeric) && mod.duration < 0
          text = "Created ban for #{user} lasting forever with reason:"
        elsif mod.duration
          text = "Created ban for #{user} lasting #{mod.duration} #{'day'.pluralize(mod.duration)} with reason:"
        else
          text = "Created ban for #{user} with reason:"
        end
        "#{text}\n[section=Reason]#{mod.reason}[/section]"
      end,
      json: %i[duration user_id reason],
    },
    ban_delete:                                 {
      text: ->(_mod, user) { "Deleted ban for #{user}" },
      json: %i[user_id],
    },
    ban_update:                                 {
      text: ->(mod, user) do
        text = "Updated ban for #{user}"
        if mod.expires_at != mod.old_expires_at
          format_expires_at = ->(timestamp) { timestamp.nil? ? "never" : DateTime.parse(timestamp).strftime("%Y-%m-%d %H:%M") }
          expires_at = format_expires_at.call(mod.expires_at)
          old_expires_at = format_expires_at.call(mod.old_expires_at)
          text += "\nChanged expiration from #{old_expires_at} to #{expires_at}"
        end
        text += "\nChanged reason: [section=Old]#{mod.old_reason}[/section] [section=New]#{mod.reason}[/section]" if mod.reason != mod.old_reason
        text
      end,
      json: %i[expires_at old_expires_at reason old_reason user_id],
    },

    ### Comment ###
    comment_delete:                             {
      text: ->(mod, user) { "Deleted comment ##{mod.subject_id} by #{user} on post ##{mod.post_id}" },
      json: %i[user_id post_id],
    },
    comment_hide:                               {
      text: ->(mod, user) { "Hid comment ##{mod.subject_id} by #{user}" },
      json: %i[user_id],
    },
    comment_unhide:                             {
      text: ->(mod, user) { "Unhid comment ##{mod.subject_id} by #{user}" },
      json: %i[user_id],
    },
    comment_update:                             {
      text: ->(mod, user) { "Edited comment ##{mod.subject_id} by #{user}" },
      json: %i[user_id],
    },

    ### Post Deletion Reason ###
    post_deletion_reason_create:                {
      text: ->(mod, _user) { "Created post deletion reason \"#{mod.reason}\"" },
      json: %i[reason],
    },
    post_deletion_reason_delete:                {
      text: ->(mod, user) { "Deleted post deletion reason \"#{mod.reason}\" by #{user}" },
      json: %i[reason user_id],
    },
    post_deletion_reasons_reorder:              {
      text: ->(mod, _user) { "Changed the order of #{mod.total} post deletion reasons." },
      json: %i[total],
    },
    post_deletion_reason_update:                {
      text: ->(mod, _user) do
        text = "Updated post deletion reason \"#{mod.reason}\""
        text += "\nChanged reason from \"#{mod.old_reason}\" to \"#{mod.reason}\"" if mod.reason != mod.old_reason
        text += "\nChanged prompt from \"#{mod.old_prompt}\" to \"#{mod.prompt}\"" if mod.prompt != mod.old_prompt
        text += "\nChanged title from \"#{mod.old_title}\" to \"#{mod.title}\"" if mod.title != mod.old_title
        text
      end,
      json: %i[reason old_reason prompt old_prompt title old_title],
    },

    ### Post Replacement Rejection Reason ###
    post_replacement_rejection_reason_create:   {
      text: ->(mod, _user) { "Created post replacement rejection reason \"#{mod.reason}\"" },
      json: %i[reason],
    },
    post_replacement_rejection_reason_delete:   {
      text: ->(mod, user) { "Deleted post replacement rejection reason \"#{mod.reason}\" by #{user}" },
      json: %i[reason user_id],
    },
    post_replacement_rejection_reasons_reorder: {
      text: ->(mod, _user) { "Changed the order of #{mod.total} post replacement rejection reasons." },
      json: %i[total],
    },
    post_replacement_rejection_reason_update:   {
      text: ->(mod, _user) do
        text = "Updated post replacement rejection reason \"#{mod.reason}\""
        text += "\nChanged reason from \"#{mod.old_reason}\" to \"#{mod.reason}\"" if mod.reason != mod.old_reason
        text
      end,
      json: %i[reason old_reason],
    },

    ### Forum Category ###
    forum_category_create:                      {
      text: ->(mod, _user) do
        text = "Created forum category ##{mod.subject_id}"
        return text unless CurrentUser.user.level >= mod.can_view
        text += " (#{mod.forum_category_name})"
        text += "\nRestricted viewing topics to #{User::Levels.id_to_name(mod.can_view)}"
        text += "\nRestricted creating topics to #{User::Levels.id_to_name(mod.can_create)}"
        text
      end,
      json: ->(mod, _user) do
              values = %i[]
              return values unless CurrentUser.user.level >= mod.can_view
              values + %i[forum_category_name can_view can_create]
            end,
    },
    forum_category_delete:                      {
      text: ->(mod, _user) do
        text = "Deleted forum category ##{mod.subject_id}"
        return text unless CurrentUser.user.level >= mod.can_view
        "#{text} (#{mod.forum_category_name})"
      end,
      json: ->(mod, _user) do
              values = %i[]
              return values unless CurrentUser.user.level >= mod.can_view
              values + %i[forum_category_name can_view can_create]
            end,
    },
    forum_category_topics_move:                 {
      text: ->(mod, _user) do
        new_category = "category ##{mod.forum_category_id}"
        new_category = "[#{mod.forum_category_name}](#{url.forum_category_path(id: mod.forum_category_id)})" if CurrentUser.user.level >= mod.can_view
        old_category = "category ##{mod.subject_id}"
        old_category = "[#{mod.old_forum_category_name}](#{url.forum_category_path(id: mod.subject_id)})" if CurrentUser.user.level >= mod.old_can_view
        "Moved all topics in #{old_category} to #{new_category}"
      end,
      json: ->(mod, _user) do
              values = %i[forum_category_id old_forum_category_id]
              values += %i[forum_category_name can_view] if CurrentUser.user.level >= mod.can_view
              values += %i[old_forum_category_name old_can_view] if CurrentUser.user.level >= mod.old_can_view
              values
            end,
    },
    forum_category_update:                      {
      text: ->(mod, _user) do
        text = "Updated forum category ##{mod.subject_id}"
        return text unless CurrentUser.user.level >= mod.can_view
        text += " (#{mod.forum_category_name})"
        text += "\nChanged name from \"#{mod.old_forum_category_name}\" to \"#{mod.forum_category_name}\"" if mod.forum_category_name != mod.old_forum_category_name
        text += "\nRestricted viewing topics to #{User::Levels.id_to_name(mod.can_view)} (Previously #{User::Levels.id_to_name(mod.old_can_view)})" if mod.can_view != mod.old_can_view
        text += "\nRestricted creating topics to #{User::Levels.id_to_name(mod.can_create)} (Previously #{User::Levels.id_to_name(mod.old_can_create)})" if mod.can_create != mod.old_can_create
        text
      end,
      json: ->(mod, _user) do
              values = %i[]
              return values unless CurrentUser.user.level >= mod.can_view
              values + %i[forum_category_name old_forum_category_name can_view old_can_view can_create old_can_create]
            end,
    },

    ### Forum Post ###
    forum_post_delete:                          {
      text: ->(mod, user) { "Deleted forum ##{mod.subject_id} in topic ##{mod.forum_topic_id} by #{user}" },
      json: %i[forum_topic_id user_id],
    },
    forum_post_hide:                            {
      text: ->(mod, user) { "Hid forum ##{mod.subject_id} in topic ##{mod.forum_topic_id} by #{user}" },
      json: %i[forum_topic_id user_id],
    },
    forum_post_unhide:                          {
      text: ->(mod, user) { "Unhid forum ##{mod.subject_id} in topic ##{mod.forum_topic_id} by #{user}" },
      json: %i[forum_topic_id user_id],
    },
    forum_post_update:                          {
      text: ->(mod, user) { "Edited forum ##{mod.subject_id} in topic ##{mod.forum_topic_id} by #{user}" },
      json: %i[forum_topic_id user_id],
    },

    ### Forum Topic ###
    forum_topic_delete:                         {
      text: ->(mod, user) { "Deleted topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_hide:                           {
      text: ->(mod, user) { "Hid topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_lock:                           {
      text: ->(mod, user) { "Locked topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_merge:                          {
      text: ->(mod, user) { "Merged topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user} into topic ##{mod.new_topic_id} (with title #{mod.new_topic_title})" },
      json: %i[forum_topic_title user_id new_topic_id new_topic_title],
    },
    forum_topic_move:                           {
      text: ->(mod, user) { "Moved topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user} from #{mod.old_forum_category_name} to #{mod.forum_category_name}" },
      json: %i[forum_topic_title user_id forum_category_id old_forum_category_id forum_category_name old_forum_category_name],
    },
    forum_topic_stick:                          {
      text: ->(mod, user) { "Stickied topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_update:                         {
      text: ->(mod, user) { "Edited topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_unhide:                         {
      text: ->(mod, user) { "Unhid topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_unlock:                         {
      text: ->(mod, user) { "Unlocked topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },
    forum_topic_unmerge:                        {
      text: ->(mod, user) { "Unmerged topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user} from topic ##{mod.old_topic_id} (with title #{mod.old_topic_title})" },
      json: %i[forum_topic_title user_id old_topic_id old_topic_title],
    },
    forum_topic_unstick:                        {
      text: ->(mod, user) { "Unstickied topic ##{mod.subject_id} (with title #{mod.forum_topic_title}) by #{user}" },
      json: %i[forum_topic_title user_id],
    },

    ### Help ###
    help_create:                                {
      text: ->(mod, _user) { "Created help page \"#{mod.name}\":/help/#{mod.name} (\"#{mod.wiki_page_title}\":#{url.wiki_page_path(id: mod.wiki_page_id)})" },
      json: %i[name wiki_page_title wiki_page_id],
    },
    help_delete:                                {
      text: ->(mod, _user) { "Deleted help page \"#{mod.name}\":/help/#{mod.name} (\"#{mod.wiki_page_title}\":#{url.wiki_page_path(id: mod.wiki_page_id)})" },
      json: %i[name wiki_page_title wiki_page_id],
    },
    help_update:                                {
      text: ->(mod, _user) { "Updated help page \"#{mod.name}\":/help/#{mod.name} (\"#{mod.wiki_page_title}\":#{url.wiki_page_path(id: mod.wiki_page_id)})" },
      json: %i[name wiki_page_title wiki_page_id],
    },

    ### Mascot ###
    mascot_create:                              {
      text: ->(mod, _user) { "Created mascot ##{mod.subject_id}" },
      json: %i[],
    },
    mascot_delete:                              {
      text: ->(mod, _user) { "Deleted mascot ##{mod.subject_id}" },
      json: %i[],
    },
    mascot_update:                              {
      text: ->(mod, _user) { "Updated mascot ##{mod.subject_id}" },
      json: %i[],
    },

    ### Bulk Update Request ###
    mass_update:                                {
      text: ->(mod, _user) { "Mass updated {{#{mod.antecedent}}} -> {{#{mod.consequent}}}" },
      json: %i[antecedent consequent],
    },
    nuke:                                       {
      text: ->(mod, _user) { "Nuked {{#{mod.query}}}" },
      json: %i[query],
    },

    ### Pools ###
    pool_delete:                                {
      text: ->(mod, user) { "Deleted pool ##{mod.subject_id} (named #{mod.pool_name}) by #{user}" },
      json: %i[pool_name user_id],
    },

    ### Post Set ###
    set_change_visibility:                      {
      text: ->(mod, user) { "Made set ##{mod.subject_id} by #{user} #{mod.is_public ? 'public' : 'private'}" },
      json: %i[is_public user_id],
    },
    set_delete:                                 {
      text: ->(mod, user) { "Deleted set ##{mod.subject_id} by #{user}" },
      json: %i[user_id],
    },
    set_update:                                 {
      text: ->(mod, user) { "Updated set ##{mod.subject_id} by #{user}" },
      json: %i[user_id],
    },

    ### Alias ###
    tag_alias_create:                           {
      text: ->(mod, _user) { "Created #{mod.alias_desc}" },
      json: %i[alias_desc],
    },
    tag_alias_update:                           {
      text: ->(mod, _user) { "Updated #{mod.alias_desc}\n#{mod.change_desc}" },
      json: %i[alias_desc change_desc],
    },

    ### Implication ###
    tag_implication_create:                     {
      text: ->(mod, _user) { "Created #{mod.implication_desc}" },
      json: %i[implication_desc],
    },
    tag_implication_update:                     {
      text: ->(mod, _user) { "Updated #{mod.implication_desc}\n#{mod.change_desc}" },
      json: %i[implication_desc change_desc],
    },

    ### Takedowns ###
    takedown_process:                           {
      text: ->(mod, _user) { "Completed takedown ##{mod.subject_id}" },
      json: %i[],
    },
    takedown_delete:                            {
      text: ->(mod, _user) { "Deleted takedown ##{mod.subject_id}" },
      json: %i[],
    },

    ### Ticket ###
    ticket_claim:                               {
      text: ->(mod, _user) { "Claimed ticket ##{mod.subject_id}" },
      json: %i[],
    },
    ticket_unclaim:                             {
      text: ->(mod, _user) { "Unclaimed ticket ##{mod.subject_id}" },
      json: %i[],
    },
    ticket_update:                              {
      text: ->(mod, _user) { "Modified ticket ##{mod.subject_id}" },
      json: %i[],
    },

    ### Upload Whitelist ###
    upload_whitelist_create:                    {
      text: ->(mod, _user) do
        return "Created whitelist entry" if mod.hidden && !CurrentUser.user.is_admin?
        "Created whitelist entry '[nodtext]#{CurrentUser.user.is_admin? ? mod.pattern : mod.note}[/nodtext]'"
      end,
      json: ->(mod, _user) {
              values = %i[hidden]
              values += %i[pattern note] if CurrentUser.user.is_admin? || !mod.hidden
              values
            },
    },
    upload_whitelist_delete:                    {
      text: ->(mod, _user) do
        return "Deleted whitelist entry" if mod.hidden && !CurrentUser.user.is_admin?
        "Deleted whitelist entry '[nodtext]#{CurrentUser.user.is_admin? ? mod.pattern : mod.note}[/nodtext]'"
      end,
      json: ->(mod, _user) {
              values = %i[hidden]
              values += %i[pattern note] if CurrentUser.user.is_admin? || !mod.hidden
              values
            },
    },
    upload_whitelist_update:                    {
      text: ->(mod, _user) do
        return "Updated whitelist entry" if mod.hidden && !CurrentUser.user.is_admin?
        return "Updated whitelist entry '[nodtext]#{mod.old_pattern}[/nodtext]' -> '[nodtext]#{mod.pattern}[/nodtext]'" if mod.old_pattern && mod.old_pattern != mod.pattern && CurrentUser.user.is_admin?
        "Updated whitelist entry '[nodtext]#{CurrentUser.user.is_admin? ? mod.pattern : mod.note}[/nodtext]'"
      end,
      json: ->(mod, _user) {
              values = %i[hidden]
              values += %i[pattern old_pattern note] if CurrentUser.user.is_admin? || !mod.hidden
              values
            },
    },

    ### User ###
    user_approve:                               {
      text: ->(_mod, user) { "Approved #{user}" },
      json: %i[user_id],
    },
    user_ban:                                   {
      text: ->(_mod, user) { "Banned #{user}" },
      json: %i[user_id],
    },
    user_blacklist_change:                      {
      text: ->(_mod, user) { "Edited blacklist of #{user}" },
      json: %i[user_id],
    },
    user_delete:                                {
      text: ->(_mod, user) { "Deleted user #{user}" },
      json: %i[user_id],
    },
    user_flags_change:                          {
      text: ->(mod, user) { "Changed #{user} flags. Added: [#{mod.added.join(', ')}] Removed: [#{mod.removed.join(', ')}]" },
      json: %i[user_id added removed],
    },
    user_level_change:                          {
      text: ->(mod, user) { "Changed #{user} level from #{mod.old_level} to #{mod.level}" },
      json: %i[user_id level old_level],
    },
    user_name_change:                           {
      text: ->(_mod, user) { "Changed name of #{user}" },
      json: %i[user_id],
    },
    user_reject:                                {
      text: ->(_mod, user) { "Rejected #{user}" },
      json: %i[user_id],
    },
    user_text_change:                           {
      text: ->(_mod, user) { "Edited profile text of #{user}" },
      json: %i[user_id],
    },
    user_upload_limit_change:                   {
      text: ->(mod, user) { "Changed upload limit of #{user} from #{mod.old_upload_limit} to #{mod.upload_limit}" },
      json: %i[user_id old_upload_limit upload_limit],
    },
    user_unban:                                 {
      text: ->(_mod, user) { "Unbanned #{user}" },
      json: %i[user_id],
    },

    ### User Feedback ###
    user_feedback_create:                       {
      text: ->(mod, user) { "Created #{mod.type} record ##{mod.subject_id} for #{user} with reason:\n[section=Reason]#{mod.reason}[/section]" },
      json: %i[type reason user_id],
    },
    user_feedback_delete:                       {
      text: ->(mod, user) { "Deleted #{mod.type} record ##{mod.subject_id} for #{user} with reason:\n[section=Reason]#{mod.reason}[/section]" },
      json: %i[type reason user_id],
    },
    user_feedback_undelete:                     {
      text: ->(mod, user) { "Undeleted #{mod.type} record ##{mod.subject_id} for #{user} with reason:\n[section=Reason]#{mod.reason}[/section]" },
      json: %i[type reason user_id],
    },
    user_feedback_destroy:                      {
      text: ->(mod, user) { "Destroyed #{mod.type} record ##{mod.subject_id} for #{user} with reason:\n[section=Reason]#{mod.reason}[/section]" },
      json: %i[type reason user_id],
    },
    user_feedback_update:                       {
      text: ->(mod, user) do
        text = "Edited record ##{mod.subject_id} for #{user}"
        text += "\nChanged type from #{mod.old_type} to #{mod.type}" if mod.type != mod.old_type
        text += "\nChanged reason: [section=Old]#{mod.old_reason}[/section] [section=New]#{mod.reason}[/section]" if mod.reason != mod.old_reason
        text
      end,
      json: %i[type old_type reason old_reason user_id],
    },

    ### Wiki ###
    wiki_page_delete:                           {
      text: ->(mod, _user) { "Deleted wiki page [[#{mod.wiki_page_title}]]" },
      json: %i[wiki_page_title],
    },
    wiki_page_merge:                            {
      text: ->(mod, _user) { "Merged wiki page [b]#{mod.wiki_page_title}[/b] into \"#{mod.target_wiki_page_title}\":#{url.wiki_page_path(id: mod.target_wiki_page_id)}" },
      json: %i[wiki_page_title target_wiki_page_id target_wiki_page_title],
    },
    wiki_page_protect:                          {
      text: ->(mod, _user) { "Restricted editing [[#{mod.wiki_page_title}]] to [#{User::Levels.id_to_name(mod.protection_level)}](/help/accounts##{User::Levels.id_to_name(mod.protection_level).downcase}) users" },
      json: %i[wiki_page_title protection_level],
    },
    wiki_page_rename:                           {
      text: ->(mod, _user) { "Renamed wiki page ([[#{mod.old_title}]] -> [[#{mod.wiki_page_title}]])" },
      json: %i[wiki_page_title old_title],
    },
    wiki_page_unprotect:                        {
      text: ->(mod, _user) { "Removed editing restrictions for [[#{mod.wiki_page_title}]]" },
      json: %i[wiki_page_title protection_level],
    },

    ### Rule ###
    rule_create:                                {
      text: ->(mod, _user) { "Created rule \"#{mod.name}\" in category \"#{mod.category_name}\" with description:\n[section=Rule Description]#{mod.description}[/section]" },
      json: %i[name description category_name],
    },
    rule_delete:                                {
      text: ->(mod, _user) { "Deleted rule \"#{mod.name}\" in category \"#{mod.category_name}\"" },
      json: %i[name category_name],
    },
    rules_reorder:                              {
      text: ->(mod, _user) { "Changed the order of #{mod.total} rules" },
      json: %i[total],
    },
    rule_update:                                {
      text: ->(mod, _user) do
        text = "Updated rule \"#{mod.name}\" in category \"#{mod.category_name}\""
        text += "\nChanged name from \"#{mod.old_name}\" to \"#{mod.name}\"" if mod.old_name != mod.name
        text += "\nChanged description: [section=Old]#{mod.old_description}[/section] [section=New]#{mod.description}[/section]" if mod.description != mod.old_description
        text += "\nChanged category from \"#{mod.old_category_name}\" to \"#{mod.category_name}\"" if mod.old_category_name != mod.category_name
        text
      end,
      json: %i[name old_name description old_description old_category_name category_name],
    },

    ### Rule Category ###
    rule_category_create:                       {
      text: ->(mod, _user) { "Created rule category \"#{mod.name}\"" },
      json: %i[name],
    },
    rule_category_delete:                       {
      text: ->(mod, _user) { "Deleted rule category \"#{mod.name}\"" },
      json: %i[name],
    },
    rule_categories_reorder:                    {
      text: ->(mod, _user) { "Changed the order of #{mod.total} rule categories" },
      json: %i[total],
    },
    rule_category_update:                       {
      text: ->(mod, _user) do
        text = "Updated rule category \"#{mod.name}\""
        text += "\nChanged name from \"#{mod.old_name}\" to \"#{mod.name}\"" if mod.old_name != mod.name
        text
      end,
      json: %i[name old_name],
    },

    ### Quick Rules ###
    quick_rule_create:                          {
      text: ->(mod, _user) { "Created quick rule #{"\"#{mod.header}\" " if mod.header.present?}with reason: #{mod.reason}" },
      json: %i[reason header],
    },
    quick_rule_delete:                          {
      text: ->(mod, _user) do
        return "Deleted quick rule with reason: #{mod.reason}" if mod.header.blank?
        "Deleted quick rule \"#{mod.header}\""
      end,
      json: %i[reason header],
    },
    quick_rules_reorder:                        {
      text: ->(mod, _user) { "Changed the order of #{mod.total} quick rules" },
      json: %i[total],
    },
    quick_rule_update:                          {
      text: ->(mod, _user) do
        text = "Updated quick rule"
        text += "\nChanged reason from \"#{mod.old_reason}\" to \"#{mod.reason}\"" if mod.reason != mod.old_reason
        text += "\nChanged header from \"#{mod.old_header}\" to \"#{mod.header}\"" if mod.header != mod.old_header
        text
      end,
      json: %i[reason old_reason header old_header],
    },

    ### Avoid Posting ###
    avoid_posting_create:                       {
      text: ->(mod, _user) { "Created avoid posting ##{mod.subject_id} for [[#{mod.artist_name}]]" },
      json: %i[artist_name],
    },
    avoid_posting_delete:                       {
      text: ->(mod, _user) { "Deleted avoid posting ##{mod.subject_id} for [[#{mod.artist_name}]]" },
      json: %i[artist_name],
    },
    avoid_posting_destroy:                      {
      text: ->(mod, _user) { "Destroyed avoid posting ##{mod.subject_id} for [[#{mod.artist_name}]]" },
      json: %i[artist_name],
    },
    avoid_posting_undelete:                     {
      text: ->(mod, _user) { "Undeleted avoid posting ##{mod.subject_id} for [[#{mod.artist_name}]]" },
      json: %i[artist_name],
    },
    avoid_posting_update:                       {
      text: ->(mod, _user) { "Updated avoid posting ##{mod.subject_id} for [[#{mod.artist_name}]]" },
      json: %i[artist_name],
    },
  }.freeze

  def format_unknown(mod, _user)
    CurrentUser.user.is_admin? ? "Unknown action #{mod.action}: #{mod.values.inspect}" : "Unknown action #{mod.action}"
  end

  def user
    "\"#{User.id_to_name(user_id)}\":/users/#{user_id}"
  end

  def self.url
    Rails.application.routes.url_helpers
  end

  def format_text
    FORMATTERS[action.to_sym]&.[](:text)&.call(self, user) || format_unknown(self, user)
  end

  def json_keys
    formatter = FORMATTERS[action.to_sym]&.[](:json)
    return CurrentUser.user.is_admin? ? values.keys : [] unless formatter
    formatter.is_a?(Proc) ? formatter.call(self, user) : formatter
  end

  def format_json
    keys = FORMATTERS[action.to_sym]&.[](:json)
    return CurrentUser.user.is_admin? ? values : {} if keys.nil?
    keys = keys.call(self, user) if keys.is_a?(Proc)
    keys.index_with(&method(:send))
  end
  KNOWN_ACTIONS = FORMATTERS.keys.freeze
  # rubocop:enable YiffSpace/CurrentUserOutsideOfRequests

  module SearchMethods
    def query_dsl
      super
        .field(:action, multi: true)
        .field(:subject_id)
        .field(:subject_type)
        .field(:ip_addr, :creator_ip_addr)
        .association(:creator)
    end
  end

  extend(SearchMethods)

  def self.without_logging(&)
    self.disable_logging = true
    yield
  ensure
    self.disable_logging = false
  end

  def serializable_hash(*)
    return super.merge("#{subject_type.underscore}_id": subject_id) if subject
    super
  end

  def self.available_includes
    %i[creator]
  end
end

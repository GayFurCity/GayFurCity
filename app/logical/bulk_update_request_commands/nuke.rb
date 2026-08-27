# frozen_string_literal: true

module BulkUpdateRequestCommands
  class Nuke < Base
    set_command(:nuke)
    set_arguments(:query, :comment)
    set_regex(/\A(?:nuke tag|nuke) ([^#]+)(?: # ?(.*))?\z/i, %i[query pass])
    set_untokenize { |query, comment| "nuke #{query}#{" # #{comment}" if comment}" }
    set_to_dtext { |query, comment| "nuke {{#{query}}} (#{Post.system_count(query, enable_safe_mode: false, include_deleted: true)})#{" # #{comment}" if comment}" }

    validate(:query_is_simple)
    validate(:user_allowed, if: -> { validation_context == :create })

    def query_is_simple
      begin
        TagQuery.new(query, User.system)
      rescue TagQuery::CountExceededError
        errors.add(:base, "query exceeds the maximum tag count")
      end
      errors.add(:base, "query is not simple") if TagQuery.has_any_metatag?(query)
    end

    def user_allowed
      errors.add(:base, "you cannot use this command") unless AdminConfig.user?(:bur_nuke, user)
    end

    def estimate_update_count
      return 0 unless valid?
      Post.system_count(query, enable_safe_mode: false, include_deleted: true)
    end

    def tags
      TagQuery.scan(query)
    end

    def process(processor, approver)
      ensure_valid!

      tags = TagQuery.scan(query)

      # Reject existing consequent implications to the tag we're nuking to ensure the tag can be removed
      if TagQuery.is_simple_tag?(tags)
        TagImplication.active.where(consequent_name: tags.first).find_each { |ti| ti.reject!(rejector: approver, update_topic: false) }
      end

      ModAction.log!(approver, :nuke, processor.request, query: query)
      Post.tag_match_sql(tags.join(" "), approver).reorder(nil).parallel_find_each do |post|
        post.with_lock do
          post.automated_edit = true
          post.updater = approver
          post.tag_string += " " + tags.map { |tag| "-#{tag}" }.join(" ") # rubocop:disable Style/StringConcatenation
          post.save
        end
      end
    end
  end
end

# frozen_string_literal: true

class BulkUpdateRequestImportPolicy < ApplicationPolicy
  def index?
    user.is_admin?
  end

  def show?
    user.is_owner?
  end

  def create?
    user.is_owner?
  end

  # Only failed imports are editable - editing exists to fix and resubmit a rejected script, not
  # to alter one that's pending/processing/already completed.
  def update?
    return create? unless record.is_a?(BulkUpdateRequestImport)
    create? && record.failed?
  end

  def permitted_attributes
    %i[script forum_topic_id]
  end

  def permitted_search_params
    params = super + %i[status forum_topic_id script_matches creator_name creator_id updater_name updater_id] + nested_search_params(creator: User, updater: User)
    params += %i[creator_ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end
end

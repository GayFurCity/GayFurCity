# frozen_string_literal: true

module Security
  class LockdownPolicy < ApplicationPolicy
    def index?
      user.is_admin?
    end

    def panic?
      user.is_admin?
    end

    def enact?
      user.is_admin?
    end

    def uploads_min_level?
      user.is_admin?
    end

    def uploads_hide_pending?
      user.is_admin?
    end

    def permitted_attributes_for_enact
      %i[uploads post_replacements pools post_sets comments forums blips aiburs favorites votes discord]
    end

    def permitted_attributes_for_uploads_min_level
      %i[min_level]
    end

    def permitted_attributes_for_uploads_hide_pending
      %i[duration]
    end
  end
end

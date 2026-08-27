# frozen_string_literal: true

class UserApproval < ApplicationRecord
  class ValidationError < StandardError; end
  belongs_to_user(:user)
  belongs_to_user(:updater, ip: true, optional: true)
  enum(:status, {
    pending:  "pending",
    approved: "approved",
    rejected: "rejected",
  })

  module SearchMethods
    def query_dsl
      super
        .field(:status)
        .association(:user)
        .association(:updater)
    end
  end

  module UpdateMethods
    def is_approvable?
      return false if user.is_banned? || status == "approved"
      return true if user.is_restricted? || user.is_rejected?
      false
    end

    def is_rejectable?
      (user.is_restricted? && status != "approved") || (user.level == User::Levels::MEMBER && status == "approved")
    end

    def approve!(approver)
      errors.add(:user, "is not approvable") unless is_approvable?
      return if errors.any?

      update(status: "approved", updater: approver)
      user.update(level: User::Levels::MEMBER)
      text = WikiPage.safe_wiki(AdminConfig.instance.user_approved_wiki_page).body.gsub("%USER_NAME%", updater_name).gsub("%USER_ID%", updater_id.to_s)
      Dmail.create_automated(to: user, title: "Your account has been approved", body: text)
      ModAction.log!(updater, :user_approve, self, user_id: user_id)
    end

    def reject!(rejector)
      errors.add(:user, "is not rejectable") unless is_rejectable?
      return if errors.any?

      update(status: "rejected", updater: rejector)
      user.update(level: User::Levels::REJECTED)
      text = WikiPage.safe_wiki(AdminConfig.instance.user_rejected_wiki_page).body.gsub("%USER_NAME%", updater_name).gsub("%USER_ID%", updater_id.to_s)
      Dmail.create_automated(to: user, title: "Your account has been rejected", body: text)
      ModAction.log!(updater, :user_reject, self, user_id: user_id)
    end
  end

  include(UpdateMethods)
  extend(SearchMethods)
end

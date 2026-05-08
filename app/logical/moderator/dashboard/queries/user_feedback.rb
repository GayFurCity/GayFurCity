# frozen_string_literal: true

module Moderator
  module Dashboard
    module Queries
      class UserFeedback
        def self.all(min_date, _max_level)
          ::UserFeedback.includes(:user)
                        .where("user_feedbacks.created_at > ?", min_date)
                        .order(id: :desc)
                        .limit(10)
        end
      end
    end
  end
end

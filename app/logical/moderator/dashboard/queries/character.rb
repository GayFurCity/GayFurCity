# frozen_string_literal: true

module Moderator
  module Dashboard
    module Queries
      Character = ::Struct.new(:user, :count) do
        def self.all(min_date, max_level)
          ::CharacterVersion.joins(:updater)
                            .where("character_versions.created_at > ?", min_date)
                            .where(users: { level: ..max_level })
                            .group(:updater)
                            .order(Arel.sql("count(*) desc"))
                            .limit(10)
                            .count
                            .map { |user, count| new(user, count) }
        end
      end
    end
  end
end

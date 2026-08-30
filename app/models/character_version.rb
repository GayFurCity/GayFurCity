# frozen_string_literal: true

class CharacterVersion < ApplicationRecord
  array_attribute(:urls)

  belongs_to_user(:updater, ip: true, counter_cache: "character_update_count")
  belongs_to(:character)
  belongs_to_user(:owner_user, optional: true)

  module SearchMethods
    def apply_order(params)
      order_with(%i[character_id name], params[:order])
    end

    def query_dsl
      super
        .field(:character_name, :name)
        .field(:character_id)
        .field(:ip_addr, :updater_ip_addr)
        .association(:updater)
    end
  end

  extend(SearchMethods)

  def previous
    CharacterVersion.where(character_id: character_id).where.lt(created_at: created_at).order(created_at: :desc).first
  end

  def self.available_includes
    %i[character updater]
  end
end

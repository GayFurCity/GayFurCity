# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  after_create(-> { DiscordNotification.new(self, :create).execute! })
  after_update(-> { DiscordNotification.new(self, :update).execute! })
  after_destroy(-> { DiscordNotification.new(self, :destroy).execute! })

  def warnings
    @warnings ||= ActiveModel::Errors.new(self)
  end

  include(::ActiveRecordExtensions)
  include(::ApiMethods)
  include(::AttributeMethods)
  include(::ConcurrencyMethods)
  include(::ConditionalIncludes)
  include(::CurrentMethods)
  include(::HasDtextLinks)
  include(::HasMediaAsset)
  include(::HasModActions)
  include(::MentionableMethods)
  include(::PrivilegeMethods)
  include(::Revertible)
  include(::Undoable)
  include(::SearchMethods)
  include(::SimpleVersioningMethods)
  include(::UserMethods)
  include(::SoftDeletable)
  include(::HasBitFlags)
  include(::UserWarnable)

  def self.override_route_key(value)
    define_singleton_method(:model_name) do
      mn = ActiveModel::Name.new(self)
      mn.instance_variable_set(:@route_key, value)
      mn
    end
  end

  def self.format_associated_message(_record, meta, _attribute)
    "is invalid: #{meta[:value].errors.full_messages.join('; ')}"
  end
end

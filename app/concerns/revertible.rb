# frozen_string_literal: true

module Revertible
  extend(ActiveSupport::Concern)

  class RevertError < StandardError; end

  module ClassMethods
    def revertible(options = {}, &block)
      raise(ArgumentError, "missing block") if block.blank?
      raise(ArgumentError, "invalid block") if block.arity != 1
      cattr_accessor(:is_revertible, :revertible_updater, :revertible_versionable_column, :revertible_block)
      self.is_revertible = true
      self.revertible_updater = options[:updater] || "updater"
      self.revertible_versionable_column = options[:versionable_column] || "#{name.underscore}_id"
      self.revertible_block = block

      class_eval do
        def revert_to(version)
          if id != version.send(self.class.revertible_versionable_column)
            raise(RevertError, "You cannot revert to a previous version of another #{self.class.model_name.human.downcase}.")
          end
          instance_exec(version, &self.class.revertible_block)
        end

        def revert_to!(version, user)
          revert_to(version)
          send("#{self.class.revertible_updater}=", user)
          save
        end
      end
    end
  end
end

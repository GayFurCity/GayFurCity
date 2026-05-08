# frozen_string_literal: true

module Undoable
  extend(ActiveSupport::Concern)

  class UndoError < StandardError; end

  module ClassMethods
    # Expects model to be revertible
    def undoable(options = {})
      cattr_accessor(:is_undoable, :undoable_relation, :undoable_id_column, :undoable_version_column)
      self.is_undoable = true
      self.undoable_relation = options[:relation] || name.delete_suffix("Version").underscore
      self.undoable_id_column = options[:id_column] || "#{name.delete_suffix('Version').underscore}_id"
      self.undoable_version_column = options[:version_column] || "version"

      class_eval do
        def undo
          version = send(self.class.undoable_version_column)
          model_id = send(self.class.undoable_id_column)
          raise(UndoError, "cannot undo version 1") if version <= 1
          raise(UndoError, "cannot undo") unless undo?
          previous = self.class.where(self.class.undoable_id_column => model_id).where.lt(version: version).order(version: :desc).first
          raise(UndoError, "no previous version") unless previous
          model = send(self.class.undoable_relation)
          model.revert_to(previous)
          model
        end

        def undo!(user)
          model = undo
          model.send("#{model.class.revertible_updater}=", user)
          model.save
        end

        def undo?
          send(self.class.undoable_version_column) > 1
        end
      end
    end
  end
end

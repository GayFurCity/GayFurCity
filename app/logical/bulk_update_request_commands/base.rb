# frozen_string_literal: true

module BulkUpdateRequestCommands
  class InvalidCommandError < StandardError; end

  class Base
    extend(ActiveModel::Naming)
    extend(ActiveModel::Translation)
    include(ActiveModel::Validations)

    class << self
      attr_reader(:command, :arguments, :regex, :groups)
    end

    attr_reader(:user)

    def initialize(user, *args)
      @user = user
      raise(InvalidCommandError, "missing arguments") if self.class.arguments.nil?
      raise(ArgumentError, "expected #{self.class.arguments.size} arguments, got #{args.size}") if self.class.arguments.size != args.size
      args.each_with_index do |value, index|
        name = self.class.arguments.at(index)
        instance_variable_set("@#{name}", value)
      end
      tag_count = self.class.arguments.select.with_index { |_name, index| self.class.groups.at(index) == :tag }.count
      self.class.arguments.each_with_index do |name, index|
        next unless self.class.groups.at(index) == :tag
        method = name == :tag_name && tag_count == 1 ? "tag" : "#{name}_tag"
        method = method.gsub("_name_", "_") if method.include?("_name_")
        define_singleton_method(method) do
          return instance_variable_get(:"@#{method}") if instance_variable_defined?(:"@#{method}")
          value = Tag.find_by(name: Tag.normalize_name(args.at(index)))
          instance_variable_set(:"@#{method}", value)
          value
        end
      end
    end

    def comments
      @comments ||= ActiveModel::Errors.new(self)
    end

    # Populated by #process for commands that support being undone (see TagMover#undos).
    # Left empty for commands that don't produce undoable side effects.
    def undo_data
      @undo_data ||= []
    end
    attr_writer(:undo_data)

    def estimate_update_count
      0
    end

    def tags
      []
    end

    def approved?
      false
    end

    def failed?
      false
    end

    def category_changes
      []
    end

    def tokenized
      self.class.arguments.map { |name| send(name) }
    end

    delegate(:command, to: :class)

    def dtext
      self.class.to_dtext(*tokenized)
    end

    def process(*)
      raise(NotImplementedError, "#{self.class}#process")
    end

    def ensure_valid!
      return if valid?
      raise(ProcessingError, "Cannot approve invalid commands: #{errors.full_messages.join(', ')}")
    end

    def merge_comment!(other)
      if other.is_a?(Base) && (other.class.has_comment? || other.is_a?(Comment))
        comment = other.comment
      else
        raise(ArgumentError, "Attempted to merge comments of class without comments: #{other.class}")
      end

      if self.class.has_comment? || instance_of?(Comment)
        tokens = tokenized
        tokens[-1] = "#{self.comment}; #{comment}"
        self.class.new(user, *tokens)
      else
        raise(ArgumentError, "Attempted to merge comment into class without comments: #{self.class}")
      end
    end

    def self.set_command(command)
      @command = command.to_sym
    end

    def self.set_arguments(*args)
      @arguments = args
      attr_reader(*args)
    end

    def self.set_regex(regex, groups)
      @regex = regex
      @groups = groups
    end

    def self.set_untokenize(&block)
      raise(InvalidCommandError, "missing groups") if groups.nil?
      raise(InvalidCommandError, "missing untokenize function") if block.nil?
      raise(InvalidCommandError, "invalid untokenize function (arity = #{block.arity}, groups = #{groups.size})") if block.arity != groups.size
      define_singleton_method(:untokenize, &block)
    end

    def self.set_to_dtext(&block)
      raise(InvalidCommandError, "missing groups") if groups.nil?
      raise(InvalidCommandError, "missing to_dtext function") if block.nil?
      raise(InvalidCommandError, "invalid to_dtext function (arity = #{block.arity}, groups = #{groups.size})") if block.arity != groups.size
      define_singleton_method(:to_dtext) do |*args|
        groups.each_with_index do |value, index|
          next if value != :tag || args.at(index).is_a?(Tag)
          args[index] = Tag.find_by(name: args.at(index)) || Tag.new(name: args.at(index))
        end
        block.call(*args)
      end
    end

    def self.matches?(line)
      return false if self == Invalid
      raise(InvalidCommandError, "missing regex") if regex.nil?
      regex.match?(line)
    end

    def self.tokenize(line)
      return [line] if self == Invalid
      raise(InvalidCommandError, "missing command") if command.nil?
      raise(InvalidCommandError, "missing regex") if regex.nil?
      raise(InvalidCommandError, "missing groups") if groups.nil?
      match = regex.match(line)
      return [nil] * groups.size if match.blank?
      raise(InvalidCommandError, "regex captures size does not match groups size") if match.captures.size != groups.size
      result = []
      match.captures.each_with_index do |value, index|
        action = groups[index]
        raise(InvalidCommandError, "missing action for index #{index} (#{value}") if action.blank?
        case action
        when :ignore
          result << nil
        when :tag
          result << Tag.normalize_name(value.to_s)
        when :downcase
          result << value.to_s.downcase
        when :query
          result << TagQuery.normalize(value.to_s)
        when :pass
          result << value
        else
          raise(InvalidCommandError, "unknown group action: #{action}")
        end
      end

      result.fill(nil, result.size...arguments.size)
    end

    def self.untokenize(*)
      raise(NotImplementedError, "#{self.class}#tokenize")
    end

    def self.to_dtext(*)
      raise(NotImplementedError, "#{self.class}#to_dtext")
    end

    def self.has_comment?
      raise(InvalidCommandError, "missing arguments") if arguments.nil?
      self != Comment && arguments.last == :comment
    end
  end
end

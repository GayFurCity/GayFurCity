# frozen_string_literal: true

class BulkUpdateRequestProcessor
  include(ActiveModel::Validations)

  class Error < RuntimeError; end
  attr_reader(:text, :topic_id, :context, :creator, :creator_ip_addr, :request)

  validate(:validate_script, unless: -> { @script_validated })
  validate(:validate_script_length)

  def initialize(text, topic_id, creator:, context: :create, ip_addr: nil, request: nil)
    @text = text
    @topic_id = topic_id
    @context = context
    @creator = creator
    @creator_ip_addr = ip_addr
    @request = request
  end

  def tokens
    @tokens ||= BulkUpdateRequestCommands.tokenize(text)
  end

  def commands
    @commands ||= BulkUpdateRequestCommands.parse(text, creator.resolvable(creator_ip_addr))
  end

  def script
    @script ||= BulkUpdateRequestCommands.untokenize(tokens, comments: false)
  end

  def dtext(tokens = self.tokens)
    BulkUpdateRequestCommands.to_dtext(tokens)
  end

  def entry_count
    commands.count { |cmd| [BulkUpdateRequestCommands::Comment, BulkUpdateRequestCommands::EmptyLine, BulkUpdateRequestCommands::Invalid].none? { |c| cmd.is_a?(c) } }
  end

  def validate_script
    commands.each { |cmd| cmd.validate(context) }
    @script_validated = true
    errors.add(:script, "is invalid: #{script_errors.map(&:full_messages).flatten.join('; ')}") if script_errors.any?(&:any?)
  end

  def validate_script_length
    limit = Config.get_user(:bur_entry_limit, creator)
    errors.add(:script, "cannot have more than #{limit} entries") if entry_count > limit
  end

  def script_errors
    validate_script unless @script_validated
    commands.map(&:errors)
  end

  def script_comments
    validate_script unless @script_validated
    commands.map(&:comments)
  end

  def script_with_errors
    return script if script_errors.blank?
    tokens = script_errors.map.with_index do |errors, index|
      token = self.tokens.at(index).dup
      has_comment = BulkUpdateRequestCommands.find_by_command(token.first).has_comment?
      if has_comment
        token[-1] = errors.full_messages.uniq.join("; ").presence
      elsif errors.any?
        raise(StandardError, "Error in #{token.first} with no comment option: #{errors.full_messages.join('; ')}")
      end
      token
    end
    BulkUpdateRequestCommands.untokenize(tokens)
  end

  def script_with_comments
    return script if script_comments.blank?
    tokens = script_comments.map.with_index do |comments, index|
      token = self.tokens.at(index).dup
      has_comment = BulkUpdateRequestCommands.find_by_command(token.first).has_comment?
      if has_comment
        token[-1] = comments.full_messages.uniq.join("; ").presence
      elsif comments.any?
        raise(StandardError, "Comment in #{token.first} with no comment option: #{comments.full_messages.join('; ')}")
      end
      token
    end
    BulkUpdateRequestCommands.untokenize(tokens)
  end

  def script_with_comments_and_errors
    return script if script_comments.blank? && script_errors.blank?
    tokens = script_comments.zip(script_errors).map.with_index do |(comments, errors), index|
      token = self.tokens.at(index).dup
      has_comment = BulkUpdateRequestCommands.find_by_command(token.first).has_comment?
      if has_comment
        token[-1] = [*comments.full_messages, *errors.full_messages].uniq.join("; ").presence
      elsif comments.any? || errors.any?
        raise(StandardError, "Comment or error in #{token.first} with no comment option: #{comments.full_messages.join('; ')} #{errors.full_messages.join('; ')}")
      end
      token
    end
    BulkUpdateRequestCommands.untokenize(tokens)
  end

  def estimate_update_count
    commands.map(&:estimate_update_count).sum
  end

  def tags
    commands.map(&:tags).flatten.uniq
  end

  def category_changes
    commands.map(&:category_changes).flatten(1)
  end

  def process!(approver)
    commands.each do |command|
      command.process(self, approver)
    end
  end
end

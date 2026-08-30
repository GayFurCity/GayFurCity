# frozen_string_literal: true

class TagNameValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    normalized = Tag.normalize_name(value)

    # These should always be checked
    case normalized
    when /\A_*\z/
      record.errors.add(attribute,  "'#{value}' cannot be blank")
    when /\A-/
      record.errors.add(attribute,  "'#{value}' cannot begin with a dash ('-')")
    when /\*/
      record.errors.add(attribute,  "'#{value}' cannot contain asterisks ('*')")
    when /,/
      record.errors.add(attribute,  "'#{value}' cannot contain commas (',')")
    when /#/
      record.errors.add(attribute,  "'#{value}' cannot contain octothorpes ('#')")
    when /[{}]/
      record.errors.add(attribute,  "'#{value}' cannot contain curly braces ('{' or '}')")
    when /%/
      record.errors.add(attribute,  "'#{value}' cannot contain percent signs ('%')")
    when /\A~/
      record.errors.add(attribute,  "'#{value}' cannot begin with a tilde ('~')")
    when /\A_/
      record.errors.add(attribute, "'#{value}' cannot begin with an underscore ('_')")
    when /_\z/
      record.errors.add(attribute, "'#{value}' cannot end with an underscore ('_')")
    when /[_\-~]{2}/
      record.errors.add(attribute, "'#{value}' cannot contain consecutive underscores, hyphens or tildes")
    when /[^[:graph:]]/
      record.errors.add(attribute, "'#{value}' cannot contain non-printable characters")
    when %r{\A[+_`(){}\[\]/]}
      record.errors.add(attribute, "'#{value}' cannot begin with a '#{value[0]}'")
    when /\A(#{TagQuery::METATAGS.join('|')}|#{TagCategory.regexp}):(.+)\z/i
      record.errors.add(attribute, "'#{value}' cannot begin with '#{$1}:'")
    when /\p{Zs}|\p{Cf}/
      record.errors.add(attribute, "'#{value}' cannot contain invisible characters")
    end

    unless options[:disable_secondary_validations]
      case normalized
      when /\$/
        record.errors.add(attribute,  "'#{value}' cannot contain peso signs ('$')")
      when /\\/
        record.errors.add(attribute,  "'#{value}' cannot contain back slashes ('\\')")
      when /\A:/
        record.errors.add(attribute,  "'#{value}' cannot begin with a colon (':')")
      end
    end

    unless options[:disable_parenthesis_check]
      if normalized =~ /(?<!_)\(/
        record.errors.add(attribute, "'#{value}' must have '(' preceded by an underscore (e.g., 'a_(bc)')")
        return
      end

      depth = 0
      normalized.each_char.with_index do |char, i|
        if char == "("
          depth += 1
        elsif char == ")"
          depth -= 1
          if depth < 0
            record.errors.add(attribute, "'#{value}' has improperly ordered parentheses (')' before '(' at position #{i})")
            break
          end
        end
      end

      if depth != 0
        record.errors.add(attribute, "'#{value}' has unbalanced parentheses")
      end
    end

    if !options[:disable_ascii_check] && normalized =~ /[^[:ascii:]]/
      record.errors.add(attribute, "'#{value}' must consist of only ASCII characters")
    end
  end
end

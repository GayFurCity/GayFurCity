# frozen_string_literal: true

module GayFurCity
  module Extensions
    module String
      # @return [Boolean] True if the string contains only balanced parentheses; false if the string contains unbalanced parentheses.
      def has_balanced_parens?(open = "(", close = ")")
        parens = 0

        chars.each do |char|
          if char == open
            parens += 1
          elsif char == close
            parens -= 1
            return false if parens < 0
          end
        end

        parens == 0
      end
    end
  end
end

class String
  include(GayFurCity::Extensions::String)
end

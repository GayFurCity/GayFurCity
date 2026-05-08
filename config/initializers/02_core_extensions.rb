# frozen_string_literal: true

module GayFurCity
  module Extensions
    module String
      def to_escaped_for_sql_like
        gsub(/%|_|\*|\\\*|\\\\|\\/) do |str|
          case str
          when "%"    then '\%'
          when "_"    then '\_'
          when "*"    then "%"
          when '\*'   then "*"
          when "\\\\", "\\" then "\\\\"
          end
        end
      end

      def truthy?
        match?(/\A(true|t|yes|y|on|1)\z/i)
      end

      def falsy?
        match?(/\A(false|f|no|n|off|0)\z/i)
      end

      def to_b
        !falsy?
      end

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

    module Enumerable
      # Like `#each`, but perform the block on each item in parallel. Note that items aren't processed in order, so things
      # like `parallel_each.map` that rely on ordering won't work.
      def parallel_each(executor = :io, &)
        return enum_for(:parallel_each, executor) unless block_given?

        parallel_map(executor, &)
        self
      end

      # Like `#map`, but in parallel.
      def parallel_map(executor = :io, &block)
        return enum_for(:parallel_map, executor) unless block_given?

        promises = map do |item|
          Concurrent::Promises.future_on(executor, item, &block)
        end

        Concurrent::Promises.zip_futures_on(executor, *promises).value!
      end
    end

    module Hash
      def to_open_hash
        OpenHash.from(self)
      end
      alias with_open_access to_open_hash
    end
  end
end

class String
  include(GayFurCity::Extensions::String)
end

module Enumerable
  include(GayFurCity::Extensions::Enumerable)
end

class Hash
  include(GayFurCity::Extensions::Hash)
end

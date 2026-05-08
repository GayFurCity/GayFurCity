# frozen_string_literal: true

module HasBitFlags
  extend(ActiveSupport::Concern)

  module ClassMethods
    # NOTE: the ordering of attributes has to be fixed
    # new attributes should be appended to the end.
    def has_bit_flags(attributes, options = {})
      field = options[:field] || :bit_flags

      define_singleton_method("flag_value_for") do |key|
        value = attributes[key.to_s]
        return value if value
        raise(ArgumentError, "Invalid flag: #{key}")
      end

      attributes.each do |name, value|
        scope(name.to_sym, -> { where.has_bits(field => value) })
        define_method(name) do
          send(field) & value == value
        end

        define_method("#{name}=") do |val|
          if val.to_s =~ /[t1y]/
            send("#{field}=", send(field) | value)
          else
            send("#{field}=", send(field) & ~value)
          end
        end

        define_method("#{name}_was") do
          send("#{field}_was") & value == value
        end

        define_method("#{name}_before_last_save") do
          send("#{field}_before_last_save") & value == value
        end

        alias_method("#{name}?", name)
        alias_method("#{name}_before_last_save?", "#{name}_before_last_save")
        alias_method("#{name}_was?", "#{name}_was")

        define_method("#{name}_changed?") do
          send("#{name}_was") != send(name)
        end

        define_method("saved_change_to_#{name}?") do
          send("#{name}_before_last_save") != send(name)
        end
      end
    end
  end
end

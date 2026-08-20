# frozen_string_literal: true

module UserWarnable
  extend(ActiveSupport::Concern)

  module ClassMethods
    def warnable
      class_eval do
        enum(:warning_type, {
          warning: 1,
          record:  2,
          ban:     3,
        })

        scope(:user_warned, -> { where.not(warning_type: nil) })
      end

      define_method(:user_warned!) do |type, user|
        update(warning_type: type, warning_user: user, updater: user)
        save_version("mark_#{type}")
      end

      define_method(:remove_user_warning!) do |user|
        update(warning_type: nil, warning_user: nil, updater: user)
        save_version("unmark")
      end

      define_method(:was_warned?) do
        !warning_type.nil?
      end

      define_method(:warning_type_string) do
        case warning_type
        when "warning"
          "User received a warning for the contents of this message"
        when "record"
          "User received a record for the contents of this message"
        when "ban"
          "User was banned for the contents of this message"
        else
          "[This is a bug with the website. Woo!]"
        end
      end
    end
  end
end

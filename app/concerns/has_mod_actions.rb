# frozen_string_literal: true

module HasModActions
  extend(ActiveSupport::Concern)

  class Builder
    def initialize(klass, prefix)
      @klass = klass
      @prefix = prefix
    end

    def add(action, ...)
      send(action, ...)
    end

    # Defines a `log_#{action}` instance method that logs a `#{prefix}_#{action}` ModAction, and,
    # if `on` is given, registers a callback (`after_#{on}` by default) to call it automatically.
    #
    # @param user_method [Symbol] method on the record returning the user to credit
    # @param details_method [Symbol, nil] method on the record returning a hash of values to log
    # @param on [Symbol, nil] lifecycle event to hook the log method into (e.g. :create, :update, :destroy)
    # @param callback [Symbol, nil] override for which callback macro to register, defaults to "after_#{on}"
    # @param callback_options [Hash] extra options forwarded to the callback macro (e.g. `unless:`)
    def method_missing(action, user_method, details_method = nil, on: nil, callback: on, **callback_options, &block)
      raise(ArgumentError, "cannot specify both a details method and a block") if details_method && block

      mod_action = :"#{@prefix}_#{action}"
      method_name = :"log_#{action}"
      callback = "after_#{on}" if on && callback == on && !(/^after|before|around/ =~ on)

      @klass.send(:define_method, method_name) do
        details =
          if block
            instance_exec(&block)
          elsif details_method
            public_send(details_method)
          else
            {}
          end
        ModAction.log!(public_send(user_method), mod_action, self, **details)
      end

      @klass.public_send(callback, method_name, **callback_options) if callback

      self
    end

    def respond_to_missing?(_action, _include_private = false)
      true
    end
  end

  class_methods do
    def modactions(prefix)
      Builder.new(self, prefix)
    end
  end
end

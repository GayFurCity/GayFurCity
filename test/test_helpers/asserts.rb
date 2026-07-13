# frozen_string_literal: true

module TestHelpers
  class Asserts
    include(Rails.application.routes.url_helpers)

    attr_reader(:klass, :pending)
    attr_accessor(:in_block)

    def initialize(klass, in_block: false)
      @klass = klass
      @in_block = in_block
      @pending = []
    end

    def access(method = nil, path = nil, &)
      caller = caller_locations(0, 2)
      builder = AssertAccessBuilder.new(klass)
      builder.caller = caller
      builder.method(method) if method
      builder.path(path) if path
      klass.instance_exec(builder, &) if block_given?
      if in_block
        @pending << builder
        builder.on_build = -> { @pending.delete(builder) }
        return builder
      end
      builder.build
      self
    end

    def search(param = nil, value = nil, records_getter = nil, &)
      caller = caller_locations(0, 2)
      builder = SearchParametersBuilder.new(klass)
      builder.caller = caller
      builder.param(param) if param
      builder.value(value) if value
      builder.records(records_getter) if records_getter
      klass.instance_exec(builder, &) if block_given?
      if in_block
        @pending << builder
        builder.on_build = -> { @pending.delete(builder) }
        return builder
      end
      builder.build
      self
    end

    def finish_pending!
      @pending.dup.each(&:build)
    end
  end
end

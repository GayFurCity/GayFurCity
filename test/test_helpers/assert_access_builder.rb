module TestHelpers
  class AssertAccessBuilder
    attr_reader(:klass)
    attr_accessor(:on_build, :caller)

    def initialize(klass)
      @klass = klass
      @path = -> { nil }
      @method = -> { :get }
      @params = -> { nil }
      @all_levels = User::Levels.constants.map { |c| User::Levels.const_get(c) }.sort - [User::Levels::ANONYMOUS, User::Levels::BANNED, User::Levels::LOCKED]
      @success_levels = @all_levels
      @fail_levels = []
      @success_response = :success
      @fail_response = :forbidden
      @anonymous_response = nil
      @anonymous_success = false
      @format = nil
      @min = false
      @max = false
      @filter = nil
    end

    def path(value = nil, &block)
      @path = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def method(value = nil, &block)
      @method = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def get(path = nil, &)
      self.path(path, &).method(:get)
    end

    def post(path = nil, &)
      self.path(path, &).method(:post)
    end

    def put(path = nil, &)
      self.path(path, &).method(:put)
    end

    def patch(path = nil, &)
      self.path(path, &).method(:patch)
    end

    def delete(path = nil, &)
      self.path(path, &).method(:delete)
    end

    def params(value = nil, &block)
      @params = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def levels(values)
      return min(values) if values.is_a?(Integer)
      @anonymous_success = true if values.include?(User::Levels::ANONYMOUS)
      @success_levels = values
      @fail_levels = @all_levels.reject { values.include?(it) }
      self
    end

    def min(value)
      @min = true
      if @max
        @success_levels = @success_levels.select { it >= value }
        @fail_levels = @all_levels.reject { @success_levels.include?(it) }
      else
        @anonymous_success = true if value <= User::Levels::ANONYMOUS
        @success_levels = @all_levels.select { it >= value }
        @fail_levels = @all_levels.reject { @success_levels.include?(it) }
      end
      self
    end

    alias level min
    alias gte min

    def max(value)
      @max = true
      if @min
        @success_levels = @success_levels.select { it <= value }
        @fail_levels = @all_levels.reject { @success_levels.include?(it) }
      else
        @anonymous_success = true if value <= User::Levels::ANONYMOUS
        @success_levels = @all_levels.select { it <= value }
        @fail_levels = @all_levels.reject { @success_levels.include?(it) }
      end
      self
    end
    alias lte max

    def between(a, b)
      min(a).max(b)
    end

    def filter(value = nil, &block)
      @filter = block || value
      self
    end

    def success(value)
      @success_response = value
      self
    end

    def fail(value)
      @fail_response = value
      self
    end

    def anonymous(value)
      @anonymous_success = true if value == :success
      @anonymous_response = value
      self
    end

    def format(value)
      @format = value
      self
    end

    def json
      format(:json)
    end

    def exec(&block)
      if block.present?
        @exec = block
        return self
      end

      method = @method
      path = @path
      params = @params
      format = @format
      get_params = proc do |user|
        value = instance_exec(*(params.arity == 0 ? [] : [user]), &params)
        if format
          value ||= {}
          value[:format] = format
        end
        value
      end
      @exec ||= ->(user) { send("#{instance_exec(*(method.arity == 0 ? [] : [user]), &method)}_auth", instance_exec(*(path.arity == 0 ? [] : [user]), &path), user, params: instance_exec(user, &get_params)) }
    end

    def build
      on_build.call if on_build.present?
      if @filter
        @success_levels = @success_levels.select { @filter.call(it) }
        @fail_levels = @all_levels.reject { @success_levels.include?(it) }
      end
      success_levels = @success_levels
      fail_levels = @fail_levels
      success_response = @success_response
      fail_response = @fail_response
      anonymous_success = @anonymous_success
      anonymous_response = @anonymous_response
      if anonymous_response.nil?
        if anonymous_success
          anonymous_response = :success
        elsif fail_response == :forbidden &&  @format != :json
          anonymous_response = :redirect
        else
          anonymous_response = fail_response
        end
      end
      exec = self.exec
      caller = [@caller&.second.then { "#{it.path}:#{it.lineno}:in 'block in asserts'" }, @caller&.first.to_s].compact
      block = proc do
        success_levels.each do |level|
          level_name = User::Levels.id_to_name(level)
          factory = :"#{level_name.downcase.tr(' ', '_')}_user"
          should("allow #{level_name}") do
            user = create(factory)
            ApplicationRecord.transaction do
              instance_exec(user, &exec)

              assert_response(success_response)
              raise(ActiveRecord::Rollback)
            end
          rescue Minitest::Assertion => e
            e.set_backtrace([*caller, *e.backtrace]) if caller.any?
            raise
          end
        end

        fail_levels.each do |level|
          level_name = User::Levels.id_to_name(level)
          factory = :"#{level_name.downcase.tr(' ', '_')}_user"
          should("not allow #{level_name}") do
            user = create(factory)
            ApplicationRecord.transaction do
              instance_exec(user, &exec)

              assert_response(fail_response)
              raise(ActiveRecord::Rollback)
            end
          rescue Minitest::Assertion => e
            e.set_backtrace([*caller, *e.backtrace]) if caller.any?
            raise
          end
        end

        User::Levels::ANONYMOUS.tap do |level|
          level_name = User::Levels.id_to_name(level)
          factory = :"#{level_name.downcase.tr(' ', '_')}_user"
          should("#{anonymous_success ? 'allow' : 'not allow'} #{level_name}") do
            user = create(factory)
            ApplicationRecord.transaction do
              instance_exec(user, &exec)

              assert_response(anonymous_response)
              raise(ActiveRecord::Rollback)
            end
          rescue Minitest::Assertion => e
            e.set_backtrace([*caller, *e.backtrace]) if caller.any?
            raise
          end
        end

        User::Levels::BANNED.tap do |level|
          level_name = User::Levels.id_to_name(level)
          factory = :"#{level_name.downcase.tr(' ', '_')}_user"
          should("not allow #{level_name}") do
            user = create(factory)
            ApplicationRecord.transaction do
              admin = create(:admin_user)
              create(:ban, user: user, reason: "test", creator: admin)
              instance_exec(user, &exec)

              assert_response(:forbidden)
              raise(ActiveRecord::Rollback)
            end
          rescue Minitest::Assertion => e
            e.set_backtrace([*caller, *e.backtrace]) if caller.any?
            raise
          end
        end
      end

      if @format
        klass.context("for #{@format}", &block)
      else
        klass.instance_exec(&block)
      end
    end
  end
end

# frozen_string_literal: true

module TestHelpers
  class SearchParametersBuilder
    attr_reader(:klass)
    attr_accessor(:on_build, :caller)

    delegate_missing_to(:klass)

    def initialize(klass, param: nil, value: nil, records_getter: nil)
      @klass = klass
      @param = param
      @value = value
      @name = nil
      @records_getter = records_getter || -> { [] }
      @user_getter = -> { create(:user) }
      @include = -> { [] }
      @ignore = -> { [] }
      @method = -> { :get }
      @path = -> { subject }
      @format = :json
      @shared = false
    end

    def param(value = nil, &block)
      @param = block || value
      self
    end

    def value(value2 = nil, &block)
      @value = block || value2
      self
    end

    def name(value)
      @name = value
      self
    end

    def records(value = nil, &block)
      @records_getter = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def user(value = nil, &block)
      @user_getter = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def include(value = nil, &block)
      @include = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def ignore(value = nil, &block)
      @ignore = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def method(value = nil, &block)
      @method = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def path(value = nil, &block)
      @path = block || (value.is_a?(Proc) ? value : -> { value })
      self
    end

    def format(value)
      @format = value
      self
    end

    def json
      format(:json)
    end

    def shared(params = nil)
      @shared = true
      @param = params
      self
    end

    def build
      on_build.presence&.call
      @name = "<value>" if @value.is_a?(Proc)
      return build_shared if @shared
      param = @param
      value = @value
      records_getter = @records_getter
      user_getter = @user_getter
      include = @include
      ignore = @ignore
      method = @method
      path = @path
      format = @format
      caller = [@caller&.second.then { "#{it.path}:#{it.lineno}:in 'block in asserts'" }, @caller&.first.to_s].compact
      klass.should("work for #{param}=#{@name || value}") do
        value = instance_exec(&value) if value.is_a?(Proc)
        records = instance_exec(&records_getter)
        user = instance_exec(&user_getter)
        method = instance_exec(&method)
        path = instance_exec(&path)
        include = instance_exec(&include)
        ignore = instance_exec(&ignore)
        # StorageManager::Base#protected_params signs file urls with the current wall-clock time
        # (auth hmac + expires). Computing "expected" via a second, separate #as_json call after
        # the request already ran can straddle a second boundary and sign a different timestamp
        # than the response did, even though both describe the same record - freeze time across
        # both so they sign identically.
        freeze_time do
          send("#{method}_auth", path, user, params: { search: { param => value }, format: format })
          expected = records.map { |r| CurrentUser.scoped(user) { r.as_json(user: user, include: include) } } # rubocop:disable YiffSpace/CurrentOutsideOfRequests
          expected = expected.map { |r| r.without(*ignore) } if ignore&.any?
          actual = @response.parsed_body.map { |r| r.try(:without, *ignore) }
          actual = actual.map { |r| r.without(*ignore) } if ignore&.any?

          assert_equal(expected, actual)
        end
      rescue Minitest::Assertion => e
        e.set_backtrace([*caller, *e.backtrace]) if caller.any?
        raise
      end
    end

    def build_shared
      records_getter = @records_getter
      user_getter = @user_getter
      method = @method
      path = @path
      format = @format
      include = @include
      ignore = @ignore
      params = @param&.map(&:to_sym)
      params ||= %i[id created_at updated_at]

      klass.instance_eval do
        asserts do
          search(:id).value { instance_exec(&records_getter).map(&:id).uniq.join(",") }.records(&records_getter).user(&user_getter).method(method).path(path).format(format).include(include).ignore(ignore) if params.include?(:id)
          search(:created_at).value { instance_exec(&records_getter).map { |x| x.created_at.to_date }.uniq.join(",") }.records(&records_getter).user(&user_getter).method(method).path(path).format(format).include(include).ignore(ignore) if params.include?(:created_at)
          search(:updated_at).value { instance_exec(&records_getter).map { |x| x.updated_at.to_date }.uniq.join(",") }.records(&records_getter).user(&user_getter).method(method).path(path).format(format).include(include).ignore(ignore) if params.include?(:updated_at)
        end
      end
    end
  end
end

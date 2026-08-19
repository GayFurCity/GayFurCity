# frozen_string_literal: true

module TestHelpers
  module Common
    extend(ActiveSupport::Concern)

    def disable_image_size_checks!
      Config.any_instance.stubs(:image_width).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      Config.any_instance.stubs(:image_height).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      Config.any_instance.stubs(:mascot_width).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      Config.any_instance.stubs(:mascot_height).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
    end

    def stub_env_config(name, value)
      GayFurCity::Config.any_instance.stubs(name).returns(value)
    end

    # Stubs the raw column instead of Config.get_user itself: Config.stubs(:get_user).with(option,
    # user) replaces get_user for every call, so any other invocation (e.g. User#statement_timeout's
    # Config.get_user(:postgres_query_timeout, user), which runs on every authenticated request via
    # SessionLoader) raises "unexpected invocation". Making the column return a non-Hash value makes
    # get_user's own logic short-circuit and hand back that value regardless of user.
    def stub_config_get_user(option, value)
      Config.any_instance.stubs(option).returns(value)
    end
  end
end

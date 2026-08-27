# frozen_string_literal: true

module TestHelpers
  module Common
    extend(ActiveSupport::Concern)

    def disable_image_size_checks!
      AdminConfig.any_instance.stubs(:image_width).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      AdminConfig.any_instance.stubs(:image_height).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      AdminConfig.any_instance.stubs(:mascot_width).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
      AdminConfig.any_instance.stubs(:mascot_height).returns({ "max" => Float::INFINITY, "min" => 0 }.with_open_access)
    end

    def stub_env_config(name, value)
      GayFurCity::Config.any_instance.stubs(name).returns(value)
    end

    def stub_admin_config(option, value, user: nil)
      if user.present?
        original = AdminConfig.method(:get_user)
        AdminConfig.define_singleton_method(:get_user) do |actual_option, actual_user, *args, **kwargs|
          if actual_option == option && actual_user == user
            value
          else
            original.call(actual_option, actual_user, *args, **kwargs)
          end
        end

        teardown do
          AdminConfig.define_singleton_method(:get_user, original)
        end
        return
      end
      AdminConfig.any_instance.stubs(option).returns(value)
    end
  end
end

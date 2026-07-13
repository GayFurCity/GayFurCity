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
  end
end

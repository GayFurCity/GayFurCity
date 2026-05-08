# frozen_string_literal: true

require("test_helper")

class UploadWhitelistTest < ActiveSupport::TestCase
  context("A upload whitelist") do
    setup do
      @user = create(:trusted_user)

      @whitelist = create(:upload_whitelist, pattern: "#{GayFurCity.config.hostname}/*", note: "local")
      if GayFurCity.config.hostname != GayFurCity.config.cdn_hostname
        @whitelist = create(:upload_whitelist, pattern: "#{GayFurCity.config.cdn_hostname}/*", note: "cdn")
      end
    end

    should("match") do
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("#{GayFurCity.config.hostname}/123.png"), @user))
      assert_equal([true, nil], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("#{GayFurCity.config.cdn_hostname}/123.png"), @user))
      assert_equal([false, "123.com not in whitelist"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png"), @user))
    end

    should("bypass for admins") do
      @user.update_columns(level: User::Levels::ADMIN)

      assert_equal([true, "bypassed"], UploadWhitelist.is_whitelisted?(Addressable::URI.parse("https://123.com/what.png"), @user))
    end
  end
end

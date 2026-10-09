# frozen_string_literal: true

require("test_helper")

class DomainIconTest < ActiveSupport::TestCase
  context("A domain icon") do
    setup do
      @admin = create(:admin_user)
    end

    should("normalize the domain and aliases") do
      icon = create(:domain_icon, creator: @admin, domain: " WWW.Example.NET ", aliases_string: "Cdn.Example.org  www.img.example.org\ncdn.example.org")

      assert_equal("example.net", icon.domain)
      assert_equal(%w[cdn.example.org img.example.org], icon.aliases)
    end

    should("store the icon") do
      icon = create(:domain_icon, creator: @admin)

      assert_predicate(icon.domain_icon_media_asset, :active?)
      assert_path_exists(icon.domain_icon_media_asset.file_path)
      assert_equal({ "domain" => icon.domain, "url" => icon.file_url(user: nil) }, DomainIcon.lookup[icon.domain])
    end

    should("not allow overlapping domains") do
      create(:domain_icon, creator: @admin, domain: "a.example.net", aliases: %w[b.example.net])

      assert_not(build(:domain_icon, creator: @admin, domain: "b.example.net").valid?)
      assert_not(build(:domain_icon, creator: @admin, domain: "c.example.net", aliases: %w[a.example.net]).valid?)
      assert_not(build(:domain_icon, creator: @admin, domain: "c.example.net", aliases: %w[b.example.net]).valid?)
      assert_predicate(build(:domain_icon, creator: @admin, domain: "c.example.net", aliases: %w[d.example.net]), :valid?)
    end

    should("reject invalid domains") do
      assert_not(build(:domain_icon, creator: @admin, domain: "not a domain").valid?)
      assert_not(build(:domain_icon, creator: @admin, domain: "example.net", aliases: %w[nope]).valid?)
    end

    should("use the size limits from the config") do
      AdminConfig.any_instance.stubs(:domain_icon_size).returns({ "min" => 64, "max" => 256 }.with_indifferent_access)
      icon = build(:domain_icon, creator: @admin)

      assert_not(icon.save)
      assert_includes(icon.errors.full_messages.join, "too small")
    end

    should("reject icons that aren't square") do
      icon = build(:domain_icon, creator: @admin, file: fixture_file_upload("test-animated-86x52.gif"))

      assert_not(icon.save)
    end

    should("update the lookup when changed") do
      icon = create(:domain_icon, creator: @admin, domain: "a.example.net")
      DomainIcon.lookup
      icon.update_with(@admin, aliases: %w[b.example.net])

      assert_equal("a.example.net", DomainIcon.lookup.dig("b.example.net", "domain"))
      icon.destroy_with(@admin, :destroyer)

      assert_nil(DomainIcon.lookup["a.example.net"])
    end

    should("replace the icon") do
      icon = create(:domain_icon, creator: @admin)
      old_asset = icon.domain_icon_media_asset
      icon.update_with(@admin, file: Rack::Test::UploadedFile.new(DomainIcon::DEFAULTS_DIR.join("furaffinity.net.png")))

      assert_equal("replaced", old_asset.reload.status)
      assert_not_equal(old_asset.id, icon.reload.domain_icon_media_asset_id)
    end

    should("create the defaults once") do
      YAML.stubs(:load_file).with(DomainIcon::DEFAULTS_FILE).returns({ "e621.net" => %w[e926.net], "furaffinity.net" => [] })

      assert_difference(-> { DomainIcon.count } => 2) { DomainIcon.create_defaults! }
      assert_no_difference(-> { DomainIcon.count }) { DomainIcon.create_defaults! }
      assert_equal(%w[e926.net], DomainIcon.find_by(domain: "e621.net").aliases)
    end

    should("have a default icon for every default domain") do
      domains = YAML.load_file(DomainIcon::DEFAULTS_FILE).keys
      files = DomainIcon::DEFAULTS_DIR.children.map { |file| file.basename(".png").to_s }

      assert_empty(domains - files, "missing icons")
      assert_empty(files - domains, "unused icons")
    end
  end
end

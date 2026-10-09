# frozen_string_literal: true

require("test_helper")

class SiteAssetTest < ActiveSupport::TestCase
  context("A site asset") do
    setup do
      @owner = create(:owner_user)
    end

    should("fall back to the default file when missing") do
      assert_equal("/images/main-icon.png", SiteAsset.file_url("favicon.ico"))
      assert_nil(SiteAsset.url_for("icon", "png_32"))
    end

    should("create the defaults once") do
      assert_difference(-> { SiteAsset.count } => SiteAsset::SLOTS.size) do
        SiteAsset.create_defaults!
      end
      assert_no_difference(-> { SiteAsset.count }) do
        SiteAsset.create_defaults!
      end
      assert_match(/_ico\.ico\z/, SiteAsset.file_url("favicon.ico"))
    end

    context("when uploaded") do
      setup do
        @asset = create(:site_asset, creator: @owner)
        @media_asset = @asset.site_media_asset
      end

      should("generate every variant") do
        slot = SiteAsset.slot("icon")

        assert_predicate(@media_asset, :active?)
        assert_equal(slot.png_sizes.map { |size| "png_#{size}" } + %w[ico], @media_asset.generated_variants)
        @media_asset.generated_variant_list.each do |variant|
          assert_predicate(variant, :file_exists?, "#{variant.type} is missing")
        end
        png = @media_asset.variants_data.find { |data| data["type"] == "png_32" }

        assert_equal([32, 32, "png"], png.values_at("width", "height", "ext"))
      end

      should("build an ico with a png for each size") do
        data = File.binread(@media_asset.find_variant!(:ico).file_path)
        _reserved, type, count = data.unpack("v3")

        assert_equal([1, 3], [type, count])
        sizes = count.times.map { |i| data[6 + (16 * i), 1].unpack1("C") }

        assert_equal([16, 32, 48], sizes)
      end

      should("serve the uploaded files") do
        assert_match(/_ico\.ico\z/, SiteAsset.file_url("favicon.ico"))
        assert_match(/_png_180\.png\z/, SiteAsset.file_url("apple-icon.png"))
      end

      should("delete the old files when replaced") do
        old_asset = @media_asset
        old_path = old_asset.find_variant!("png_32").file_path
        @asset.update_with(@owner, file: fixture_file_upload("test-square-568.png"))

        assert_equal("replaced", old_asset.reload.status)
        assert_not(File.exist?(old_path))
        assert_not_equal(old_asset.id, @asset.reload.site_media_asset_id)
        assert_predicate(@asset.site_media_asset.find_variant!("png_32"), :file_exists?)
      end

      should("go back to the defaults when deleted") do
        path = @media_asset.find_variant!("png_32").file_path
        @asset.destroy_with(@owner, :destroyer)

        assert_not(File.exist?(path))
        assert_equal("/images/main-icon.png", SiteAsset.file_url("favicon.ico"))
      end
    end

    should("reject images that aren't square") do
      asset = build(:site_asset, creator: @owner, file: fixture_file_upload("test.png"))

      assert_not(asset.save)
      assert_includes(asset.errors.full_messages.join, "must be square")
    end

    should("reject images that are too small") do
      asset = build(:site_asset, creator: @owner, file: fixture_file_upload("test-square-256.png"))

      assert_not(asset.save)
      assert_includes(asset.errors.full_messages.join, "too small")
    end

    should("reject unknown names") do
      asset = build(:site_asset, creator: @owner, name: "nope")

      assert_not(asset.valid?)
      assert_includes(asset.errors[:name], "is not included in the list")
    end
  end
end

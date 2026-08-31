# frozen_string_literal: true

class AddMinImageWidthAndHeightToConfig < ExtendedMigration[7.1]
  with_config_override!

  DEFAULT_IMAGE_MAX = 40_000
  DEFAULT_IMAGE_MIN = 300
  DEFAULT_MASCOT_MAX = 1000
  DEFAULT_MASCOT_MIN = 250

  def up
    up_image
    up_mascot
  end

  def up_image
    max_width = Config.get.max_image_width
    default_width = Config.column_defaults["max_image_width"].to_i
    max_height = Config.get.max_image_height
    default_height = Config.column_defaults["max_image_height"].to_i
    add_column(:config, :image_width, :jsonb, default: {
      min: DEFAULT_IMAGE_MIN,
      max: default_width,
    }, null: false)
    add_column(:config, :image_height, :jsonb, default: {
      min: DEFAULT_IMAGE_MIN,
      max: default_height,
    }, null: false)
    remove_column(:config, :max_image_width)
    remove_column(:config, :max_image_height)
    if max_width != default_width
      Config.where(id: Config.config_id).update_all(["image_width = ?", {
        min: DEFAULT_IMAGE_MIN,
        max: max_width,
      }.to_json,])
    end
    if max_height != default_height
      Config.where(id: Config.config_id).update_all(["image_height = ?", {
        min: DEFAULT_IMAGE_MIN,
        max: max_height,
      }.to_json,])
    end
    Config.delete_cache
  end

  def up_mascot
    max_width = Config.get.max_mascot_width
    default_width = Config.column_defaults["max_mascot_width"].to_i
    max_height = Config.get.max_mascot_height
    default_height = Config.column_defaults["max_mascot_height"].to_i
    add_column(:config, :mascot_width, :jsonb, default: {
      min: DEFAULT_MASCOT_MIN,
      max: default_width,
    }, null: false)
    add_column(:config, :mascot_height, :jsonb, default: {
      min: DEFAULT_MASCOT_MIN,
      max: default_height,
    }, null: false)
    remove_column(:config, :max_mascot_width)
    remove_column(:config, :max_mascot_height)
    if max_width != default_width
      Config.where(id: Config.config_id).update_all(["mascot_width = ?", {
        min: DEFAULT_MASCOT_MIN,
        max: max_width,
      }.to_json,])
    end
    if max_height != default_height
      Config.where(id: Config.config_id).update_all(["mascot_height = ?", {
        min: DEFAULT_MASCOT_MIN,
        max: max_height,
      }.to_json,])
    end
    Config.delete_cache
  end

  def down
    down_image
    down_mascot
  end

  def down_image
    max_width = Config.get.image_width["max"]
    default_width = (Config.column_defaults["image_width"] || {})["max"] || DEFAULT_IMAGE_MAX
    max_height = Config.get.image_height["max"]
    default_height = (Config.column_defaults["image_height"] || {})["max"] || DEFAULT_IMAGE_MAX
    add_column(:config, :max_image_width, :integer, default: default_width, null: false)
    add_column(:config, :max_image_height, :integer, default: default_height, null: false)
    remove_column(:config, :image_width)
    remove_column(:config, :image_height)
    if max_width != default_width
      Config.where(id: Config.config_id).update_all(["max_image_width = ?", max_width])
    end
    if max_height != default_height
      Config.where(id: Config.config_id).update_all(["max_image_height = ?", max_height])
    end
    Config.delete_cache
  end

  def down_mascot
    max_width = Config.get.mascot_width["max"]
    default_width = (Config.column_defaults["mascot_width"] || {})["max"] || DEFAULT_MASCOT_MAX
    max_height = Config.get.mascot_height["max"]
    default_height = (Config.column_defaults["mascot_height"] || {})["max"] || DEFAULT_MASCOT_MAX
    add_column(:config, :max_mascot_width, :integer, default: default_width, null: false)
    add_column(:config, :max_mascot_height, :integer, default: default_height, null: false)
    remove_column(:config, :mascot_width)
    remove_column(:config, :mascot_height)
    if max_width != default_width
      Config.where(id: Config.config_id).update_all(["max_mascot_width = ?", max_width])
    end
    if max_height != default_height
      Config.where(id: Config.config_id).update_all(["max_mascot_height = ?", max_height])
    end
    Config.delete_cache
  end
end

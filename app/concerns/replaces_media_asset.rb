# frozen_string_literal: true

module ReplacesMediaAsset
  # Swaps in a new media asset when a file is given on update, and removes the old asset's files
  def replace_media_asset(attribute, **attributes)
    return if file.blank?
    file = self.file
    self.file = nil
    old_asset = public_send(attribute)
    new_asset = old_asset.class.new(creator: updater, checksum: MediaAsset.md5(file.path), **attributes)
    new_asset.append_all!(file, save: false)
    if new_asset.valid? && new_asset.active?
      # saved before being assigned, otherwise it saves this record again through the inverse association
      new_asset.save!
      public_send("#{attribute}=", new_asset)
      old_asset.updater = updater
      old_asset.delete_all_files
      old_asset.update_columns(status: "replaced")
    else
      errors.merge!(new_asset.errors)
      errors.add(:file, new_asset.status_message) if new_asset.status_message.present? && errors.empty?
      throw(:abort)
    end
  end
end

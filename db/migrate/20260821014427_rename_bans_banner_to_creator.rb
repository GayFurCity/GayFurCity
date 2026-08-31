# frozen_string_literal: true

class RenameBansBannerToCreator < ExtendedMigration[8.1]
  def change
    rename_column(:bans, :banner_id, :creator_id)
    rename_column(:bans, :banner_ip_addr, :creator_ip_addr)
  end
end

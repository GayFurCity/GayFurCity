# frozen_string_literal: true

class RenameBansCreatorIpAddrNotNullConstraint < ExtendedMigration[8.1]
  def change
    reversible do |dir|
      dir.up   { rename_constraint(:bans, "bans_banner_ip_addr_not_null", "bans_creator_ip_addr_not_null") }
      dir.down { rename_constraint(:bans, "bans_creator_ip_addr_not_null", "bans_banner_ip_addr_not_null") }
    end
  end
end

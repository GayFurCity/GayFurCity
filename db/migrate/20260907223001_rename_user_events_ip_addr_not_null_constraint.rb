# frozen_string_literal: true

# db/migrate/20250620164659_updaters_creators_and_ip_addrs.rb renamed ip_addr -> user_ip_addr, but
# Postgres doesn't rename the column's NOT NULL constraint along with it - it's still named after
# "ip_addr".
class RenameUserEventsIpAddrNotNullConstraint < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up   { rename_constraint_if_exists(:user_events, "user_events_ip_addr_not_null", "user_events_user_ip_addr_not_null") }
      dir.down { rename_constraint_if_exists(:user_events, "user_events_user_ip_addr_not_null", "user_events_ip_addr_not_null") }
    end
  end
end

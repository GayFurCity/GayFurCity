# frozen_string_literal: true

class RemovePostReportReasons < ActiveRecord::Migration[7.1]
  def change
    drop_table(:post_report_reasons) do |t|
      t.string(:reason, null: false)
      t.integer(:creator_id, null: false)
      t.inet(:creator_ip_addr)
      t.string(:description, null: false)
      t.timestamps
    end

    remove_column(:tickets, :report_reason, :string)
  end
end

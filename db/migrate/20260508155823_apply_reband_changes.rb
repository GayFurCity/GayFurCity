# frozen_string_literal: true

class ApplyRebandChanges < ExtendedMigration[7.1]
  def change
    change_column_default(:config, :app_name, from: "Femboy Fans", to: "GayFur City")
    change_column_default(:config, :canonical_app_name, from: "Femboy Fans", to: "GayFur City")
    change_column_default(:config, :app_description, from: "Your one-stop shop for femboy furries.", to: "Your one-stop shop for gay furries.")
    change_column_default(:config, :takedown_email, from: "admin@femboy.fan", to: "admin@gayfur.city")
    change_column_default(:config, :contact_email, from: "admin@femboy.fan", to: "admin@gayfur.city")
  end
end

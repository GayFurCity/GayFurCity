# frozen_string_literal: true

require("test_helper")

class ConfigHelperTest < ActionView::TestCase
  context("ConfigHelper#boolean_config_field") do
    # The hidden "false" fallback and the checkbox share the same param name - when a form submits
    # both (which happens whenever the checkbox is checked), whichever one appears later in the
    # request wins. The hidden fallback has to come first in the markup, or a checked box can never
    # actually be saved as true (see app/helpers/config_helper.rb).
    should("render the hidden fallback before the checkbox in the markup") do
      owner = create(:owner_user)
      config = AdminConfig.instance

      html = CurrentUser.scoped(owner) { boolean_config_field(config, :db_exports_enabled) } # rubocop:disable YiffSpace/CurrentOutsideOfRequests

      hidden_index = html.index('type="hidden"')
      checkbox_index = html.index('type="checkbox"')

      assert(hidden_index, "expected a hidden fallback field to be rendered")
      assert(checkbox_index, "expected a checkbox to be rendered")
      assert_operator(hidden_index, :<, checkbox_index)
    end

    # The checkbox's `value` attribute (what it submits when checked) must be a fixed "true"
    # sentinel, not the field's current stored value. Otherwise a field that's currently false
    # renders as <input type="checkbox" value="false" ...> - checking it and submitting still
    # sends "false", so it can never actually be turned on through the UI.
    should("render the checkbox's value as a fixed true sentinel regardless of the field's current value") do
      owner = create(:owner_user)
      config = AdminConfig.instance
      config.update_column(:db_exports_enabled, false)

      html = CurrentUser.scoped(owner) { boolean_config_field(config, :db_exports_enabled) } # rubocop:disable YiffSpace/CurrentOutsideOfRequests
      checkbox = html[/<input type="checkbox"[^>]*>/]

      assert(checkbox, "expected a checkbox to be rendered")
      assert_includes(checkbox, 'value="true"')
    end
  end
end

# frozen_string_literal: true

# A row per external identity connected to a user's account (e.g. "Login with YiffSpace"). Generic
# by design - `provider` identifies which integration created the row, `uid` is that provider's own
# identifier for the connected identity, and `data`/`display_name` are for whatever that provider
# wants to show in the UI. Adding a new connectable provider is just a new PROVIDERS entry plus
# whatever controller drives its own OAuth/link flow - no schema changes needed.
class LinkedAccount < ApplicationRecord
  # connect_path is called with the view context, and should return wherever the "Connect"
  # link should point - normally the provider's own OAuth entry point, passed a `path` back
  # to Users::YiffspaceController#callback (or an equivalent for a future provider) so it
  # knows to link to the signed-in user rather than trying to sign someone in.
  PROVIDERS = {
    "yiffspace" => {
      name:         "YiffSpace",
      icon:         "fa-brands fa-discord",
      connect_path: ->(view) { view.yiffspace_auth_path(path: view.users_yiffspace_callback_path) },
    }.freeze,
  }.freeze

  belongs_to(:user)

  validates(:provider, presence: true, inclusion: { in: PROVIDERS.keys })
  validates(:uid, presence: true, uniqueness: { scope: :provider })
  validates(:provider, uniqueness: { scope: :user_id })

  def provider_name
    PROVIDERS.dig(provider, :name) || provider.titleize
  end
end

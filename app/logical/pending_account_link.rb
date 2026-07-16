# frozen_string_literal: true

# Bridges a just-verified external identity (e.g. landed on Users::YiffspaceController#callback with
# no local account already linked to it) into a LinkedAccount once the user proves ownership of that
# account the normal way - either by logging in with their password (including MFA, if set) or by
# completing signup. Call #finalize! right after a login/signup establishes session[:user_id].
class PendingAccountLink
  SESSION_KEY = :pending_account_link

  def self.stash!(session, provider:, uid:, display_name: nil)
    session[SESSION_KEY] = { "provider" => provider.to_s, "uid" => uid.to_s, "display_name" => display_name }
  end

  def self.finalize!(session, user, request:, category:)
    pending = session.delete(SESSION_KEY)
    return if pending.blank? || user.blank?

    existing = user.linked_accounts.find_by(provider: pending["provider"])
    return if existing.present? && existing.uid != pending["uid"] # already linked to a different identity for this provider, don't clobber it
    return if existing&.uid == pending["uid"]

    link = user.linked_accounts.create!(provider: pending["provider"], uid: pending["uid"], display_name: pending["display_name"])
    UserEvent.create_from_request!(user, category, request, metadata: { "provider" => link.provider })
  rescue ActiveRecord::RecordInvalid
    # Another account claimed this identity in the meantime (e.g. two tabs finishing the flow at
    # once), or some other validation failure - leave this login/signup alone either way.
    nil
  end
end

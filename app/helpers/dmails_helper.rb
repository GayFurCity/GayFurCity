# frozen_string_literal: true

module DmailsHelper
  def all_dmails_path(params = {})
    dmails_path(folder: "all", **params)
  end

  def sent_dmails_path(params = {})
    dmails_path(folder: "sent", **params)
  end

  def received_dmails_path(params = {})
    dmails_path(folder: "received", **params)
  end

  # reference_data is deliberately unstructured (see db/migrate/*_add_reference_data_to_dmails.rb)
  # so this only special-cases the sources that actually exist today - anything else (or a dmail
  # with no reference_data at all) renders nothing.
  def dmail_reference_source(dmail)
    data = dmail.reference_data
    return nil if data.blank?
    case data["type"]
    when "ticket"
      ticket = Ticket.find_by(id: data["ticket_id"])
      if ticket&.visible?(CurrentUser.user)
        link_to("Ticket ##{ticket.id}", ticket_path(ticket))
      else
        "Ticket ##{data['ticket_id']}"
      end
    else
      data["type"]&.titleize
    end
  end
end

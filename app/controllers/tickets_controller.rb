# frozen_string_literal: true

class TicketsController < ApplicationController
  respond_to(:html, :json, except: %i[create new])

  def index
    @tickets = authorize(Ticket).html_includes(request, :creator, :accused, :claimant, :model)
                                .search_current(search_params(Ticket))
                                .paginate(params[:page], limit: params[:limit])
    respond_with(@tickets)
  end

  def show
    @ticket = authorize(Ticket.find(params[:id]))
    @ticket_messages = @ticket.ticket_messages.includes(:creator)
    respond_with(@ticket)
  end

  def new
    authorize(Ticket)
    @ticket = Ticket.new_with_current(:creator, permitted_attributes(Ticket))
    if @ticket.model_type.present? && Ticket::MODELS.types.exclude?(@ticket.model_type)
      return render_expected_error(404, "Invalid ticket type")
    end
    authorize(@ticket)
  end

  def create
    authorize(Ticket)
    @ticket = Ticket.new_with_current(:creator, permitted_attributes(Ticket))
    if @ticket.model_type.present? && Ticket::MODELS[:types].exclude?(@ticket.model_type)
      return render_expected_error(404, "Invalid ticket type")
    end
    authorize(@ticket)
    if @ticket.valid?
      @ticket.save
      notice("Ticket created")
      redirect_to(ticket_path(@ticket))
    else
      respond_with(@ticket)
    end
  end

  def update
    @ticket = authorize(Ticket.find(params[:id]))
    @ticket_messages = @ticket.ticket_messages.includes(:creator)
    if @ticket.claimant_id.present? && @ticket.claimant_id != CurrentUser.user.id && !params[:force_claim].to_s.truthy?
      notice("Ticket has already been claimed by somebody else, submit again to force")
      redirect_to(ticket_path(@ticket, force_claim: "true"))
      return
    end

    ticket_params = permitted_attributes(@ticket)
    # A message is optional here - a moderator may just be changing the status, locking the
    # ticket, etc. without needing to leave a reply.
    message = ticket_params[:message].presence && TicketMessage.new(ticket: @ticket, creator: CurrentUser.user, body: ticket_params[:message], skip_reply_effects: true)

    if message&.invalid?
      @ticket.errors.add(:base, message.errors[:body].first || "Message is invalid")
    else
      @ticket.transaction do
        if @ticket.warnable? && ticket_params[:record_type].present?
          @ticket.content.user_warned!(ticket_params[:record_type].to_i, CurrentUser.user)
        end

        @ticket.handler = CurrentUser.user
        @ticket.claimant = CurrentUser.user
        @ticket.update_with_current(:updater, ticket_params)
        message.save! if message && @ticket.errors.empty?
      end
    end

    @ticket.respond!(CurrentUser.user, message: message, force_dmail: ticket_params[:send_update_dmail].to_s.truthy?) if @ticket.errors.empty?

    respond_with(@ticket)
  end

  def claim
    @ticket = authorize(Ticket.find(params[:id]))

    if @ticket.claimant.nil?
      @ticket.claim!(CurrentUser.user)
      redirect_to(ticket_path(@ticket))
      return
    end
    notice("Ticket already claimed")
    redirect_to(ticket_path(@ticket))
  end

  def unclaim
    @ticket = authorize(Ticket.find(params[:id]))

    if @ticket.claimant.nil?
      notice("Ticket not claimed")
      redirect_to(ticket_path(@ticket))
      return
    elsif @ticket.claimant.id != CurrentUser.user.id
      notice("Ticket not claimed by you")
      redirect_to(ticket_path(@ticket))
      return
    elsif @ticket.approved? || @ticket.rejected?
      notice("Cannot unclaim approved/rejected ticket")
      redirect_to(ticket_path(@ticket))
      return
    end
    @ticket.unclaim!(CurrentUser.user)
    notrice("Claim removed")
    redirect_to(ticket_path(@ticket))
  end
end

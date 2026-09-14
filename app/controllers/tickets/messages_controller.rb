# frozen_string_literal: true

module Tickets
  class MessagesController < ApplicationController
    respond_to(:html, except: %i[index])
    respond_to(:json)

    def index
      @ticket = Ticket.find(params[:ticket_id])
      authorize(@ticket, policy_class: TicketMessagePolicy)
      @ticket_messages = @ticket.ticket_messages.includes(:creator)
                                .paginate(params[:page], limit: params[:limit])
      respond_with(@ticket_messages)
    end

    def create
      @ticket = Ticket.find(params[:ticket_id])
      @message = authorize(@ticket.ticket_messages.new(creator: CurrentUser.user))
      @message.assign_attributes(permitted_attributes(@message))
      @message.save

      respond_to do |format|
        format.html do
          notice(@message.errors.full_messages.join(", ")) unless @message.persisted?
          redirect_to(ticket_path(@ticket))
        end
        format.json { respond_with(@message, location: ticket_path(@ticket)) }
      end
    end

    def destroy
      @ticket = Ticket.find(params[:ticket_id])
      @message = authorize(@ticket.ticket_messages.find(params[:id]))
      @message.destroy

      respond_to do |format|
        format.html { redirect_to(ticket_path(@ticket)) }
        format.json
      end
    end
  end
end

# frozen_string_literal: true

class StaffNotesController < ApplicationController
  before_action(:load_staff_note, only: %i[update destroy])
  respond_to(:html, :json)

  def index
    @user = User.find_by(id: params[:user_id])
    sparams = search_params(StaffNote)
    sparams[:user_id] = params[:user_id] if @user
    @notes = authorize(StaffNote).html_includes(request, :user, :creator)
                                 .search_current(sparams)
                                 .paginate(params[:page], limit: params[:limit])
    respond_with(@notes)
  end

  def new
    @user = User.find(params[:user_id])
    @staff_note = authorize(StaffNote.new_with_current(:creator, permitted_attributes(StaffNote).merge(user_id: @user.id)))
    respond_with(@note)
  end

  def create
    @user = User.find(params[:user_id])
    @staff_note = authorize(StaffNote.new_with_current(:creator, permitted_attributes(StaffNote).merge({ user_id: @user.id })))
    @staff_note.save
    flash[:notice] = @staff_note.valid? ? "Staff Note added" : @staff_note.errors.full_messages.join("; ")
    respond_with(@staff_note) do |format|
      format.html do
        redirect_back_or_to(staff_notes_path)
      end
    end
  end

  def update
    authorize(@staff_note).update_with_current(:updater, permitted_attributes(@staff_note))
    redirect_back_or_to(staff_notes_path)
  end

  def destroy
    authorize(@staff_note).update_with_current(:updater, is_deleted: true)
    redirect_back_or_to(staff_notes_path)
  end

  def undelete
    @staff_note = authorize(StaffNote.find(params[:staff_note_id]))
    @staff_note.update_with_current(:updater, is_deleted: false)
    redirect_back_or_to(staff_notes_path)
  end

  private

  def load_staff_note
    @staff_note = StaffNote.find(params[:id])
  end
end

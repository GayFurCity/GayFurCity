# frozen_string_literal: true

class AvoidPostingsController < ApplicationController
  respond_to(:html, :json)
  before_action(:load_avoid_posting, except: %i[index new create])
  helper_method(:search_params)

  def index
    @avoid_postings = authorize(AvoidPosting).html_includes(request, :artist, :creator)
                                             .search_current(search_params(AvoidPosting))
                                             .paginate(params[:page], limit: params[:limit])
    respond_with(@avoid_postings)
  end

  def show
    authorize(@avoid_posting)
    respond_with(@avoid_posting)
  end

  def new
    @avoid_posting = authorize(AvoidPosting.new_with_current(:creator, permitted_attributes(AvoidPosting)))
    @avoid_posting.artist = Artist.new_with_current(:creator, permitted_attributes(AvoidPosting)[:artist_attributes])
    respond_with(@artist)
  end

  def edit
    authorize(@avoid_posting)
  end

  def create
    pparams = permitted_attributes(AvoidPosting)
    @avoid_posting = authorize(AvoidPosting.new_with_current(:creator, pparams))
    artparams = pparams.try(:[], :artist_attributes)
    if artparams.present? && (artist = Artist.named(artparams[:name]))
      @avoid_posting.artist = artist
      notices = []
      if artist.other_names.present? && (artparams.key?(:other_names_string) || artparams.key?(:other_names))
        on = artparams[:other_names_string].try(:split) || artparams[:other_names]
        artparams.delete(:other_names_string)
        artparams.delete(:other_names)
        if on.present?
          artparams[:other_names] = (artist.other_names + on).uniq
          notices << "Artist already had other names, the provided names were merged into the existing names."
        end
      end
      if artist.linked_user_id.present? && artparams.key?(:linked_user_id)
        if artparams[:linked_user_id].present?
          notices << "Artist is already linked to \"#{artist.linked_user.name}\":/users/#{artist.linked_user_id}, no change was made."
        end
        artparams.delete(:linked_user_id)
      end
      notices = notices.join("\n")
      # Remove period from last notice
      flash[:notice] = notices[0..-2] if notices.present?
      artist.update_with_current(:updater, artparams)
    end
    @avoid_posting.save
    respond_with(@avoid_posting)
  end

  def update
    pparams = permitted_attributes(@avoid_posting)
    @avoid_posting.artist.updater = CurrentUser.user if pparams[:artist_attributes].present?
    authorize(@avoid_posting).update_with_current(:updater, pparams)
    notice(@avoid_posting.valid? ? "Avoid posting entry updated" : @avoid_posting.errors.full_messages.join("; "))
    respond_with(@avoid_posting)
  end

  def destroy
    authorize(@avoid_posting).destroy_with_current(:destroyer)
    notice("Avoid posting entry destroyed")
    respond_with(@avoid_posting) do |format|
      format.html { redirect_to(artist_path(@avoid_posting.artist)) }
    end
  end

  def delete
    authorize(@avoid_posting).soft_delete_with_current(:updater)
    notice("Avoid posting entry deleted")
    respond_with(@avoid_posting) do |format|
      format.html { redirect_back_or_to(avoid_posting_path(@avoid_posting)) }
    end
  end

  def undelete
    authorize(@avoid_posting).soft_undelete_with_current(:updater)
    notice("Avoid posting entry undeleted")
    respond_with(@avoid_posting) do |format|
      format.html { redirect_back_or_to(avoid_posting_path(@avoid_posting)) }
    end
  end

  private

  def load_avoid_posting
    id = params[:id]
    if id =~ /\A\d+\z/
      @avoid_posting = AvoidPosting.find(id)
    else
      @avoid_posting = AvoidPosting.joins(:artist).find_by!("artists.name": id)
    end
  end
end

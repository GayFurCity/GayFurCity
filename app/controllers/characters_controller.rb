# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action(:load_character, only: %i[edit update destroy revert])
  respond_to(:html, :json)

  def index
    if params[:name].present?
      @character = Character.find_by(name: Character.normalize_name(params[:id]))
      if @character.nil?
        return redirect_to(show_or_new_characters_path(name: params[:id])) if request.format.html?
        raise(ActiveRecord::RecordNotFound)
      end
      redirect_to(character_path(@character))
    end
    @characters = authorize(Character).includes(:urls)
                                      .search_current(search_params(Character))
                                      .paginate(params[:page], limit: params[:limit])
    respond_with(@characters) do |format|
      format.json do
        render(json: @characters.to_json(include: %i[urls]))
        expires_in(params[:expiry].to_i.days) if params[:expiry]
      end
    end
  end

  def show
    if params[:id] =~ /\A\d+\z/
      @character = Character.find(params[:id])
    else
      @character = Character.named(name: params[:id])
      unless @character
        respond_to do |format|
          format.html do
            redirect_to(show_or_new_characters_path(name: params[:id]))
          end
          format.json do
            raise(ActiveRecord::RecordNotFound)
          end
        end
        return
      end
    end
    authorize(@character)
    @post_set = PostSets::Post.new(@character.name, 1, limit: 10, current_user: CurrentUser.user)
    respond_with(@character, include: %i[urls])
  end

  def new
    @character = authorize(Character.new_with_current(:creator, permitted_attributes(Character)))
    respond_with(@character)
  end

  def edit
    authorize(@character)
    respond_with(@character)
  end

  def create
    pparams = permitted_attributes(Character)
    url_string = pparams.delete(:url_string)
    @character = authorize(Character.new_with_current(:creator, pparams))
    # FIXME: This is a hack on top of a hack to ensure all of the other attributes are set before url_string to ensure there are no race conditions
    @character.url_string = url_string unless url_string.nil?
    @character.save
    respond_with(@character)
  end

  def update
    authorize(@character).update_with_current(:updater, permitted_attributes(@character))
    notice(@character.valid? ? "Character updated" : @character.errors.full_messages.join("; "))
    respond_with(@character)
  end

  def destroy
    authorize(@character).destroy_with_current(:destroyer)
    respond_with(@character) do |format|
      format.html do
        redirect_to(characters_path, notice: @character.destroyed? ? "Character deleted" : @character.errors.full_messages.join("; "))
      end
    end
  end

  def revert
    authorize(@character)
    @version = @character.versions.find(params[:version_id])
    @character.revert_to!(@version, CurrentUser.user)
    respond_with(@character)
  end

  def show_or_new
    @character = authorize(Character).named(params[:name])
    if @character
      redirect_to(character_path(@character))
    else
      @character = Character.new(name: Character.normalize_name(params[:name] || ""))
      @post_set = PostSets::Post.new(@character.name, 1, limit: 10, current_user: CurrentUser.user)
      respond_with(@character)
    end
  end

  private

  def load_character
    if params[:id] =~ /\A\d+\z/
      @character = Character.find(params[:id])
    else
      @character = Character.named(name: params[:id])
      raise(ActiveRecord::RecordNotFound) if @character.blank?
    end
  end
end

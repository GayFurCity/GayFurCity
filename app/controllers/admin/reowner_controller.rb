# frozen_string_literal: true

module Admin
  class ReownerController < ApplicationController
    wrap_parameters(:reowner)

    def new
      authorize(:reowner)
    end

    def create
      authorize(:reowner)
      @reowner_params = permitted_attributes(:reowner)
      @old_user = User.find_by_normalized_name_or_id(@reowner_params[:old_owner])
      @new_user = User.find_by_normalized_name_or_id(@reowner_params[:new_owner])
      query = @reowner_params[:search]
      unless @old_user && @new_user
        flash[:notice] = "Old or new user failed to look up. Use !id for name to use an id"
        redirect_back_or_to(new_admin_reowner_path)
        return
      end

      moved_post_ids = []
      Post.tag_match_current("user:!#{@old_user.id} #{query}").limit(300).each do |p|
        moved_post_ids << p.id
        p.do_not_version_changes = true
        p.updater = CurrentUser.user
        p.update(uploader_id: @new_user.id)
        p.versions.where(updater_id: @old_user.id).find_each do |pv|
          pv.update_column(:updater_id, @new_user.id)
          pv.update_index
        end
      end

      StaffAuditLog.log!(CurrentUser.user, :post_owner_reassign, new_user_id: @new_user.id, old_user_id: @old_user.id, query: query, post_ids: moved_post_ids)
      flash[:notice] = "Post ownership reassigned"
      redirect_back_or_to(new_admin_reowner_path)
    end
  end
end

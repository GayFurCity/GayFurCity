# frozen_string_literal: true

module BulkUpdateRequests
  class ImportsController < ApplicationController
    respond_to(:html, :json)
    before_action(:load_import, only: %i[show edit update])

    def index
      @imports = authorize(BulkUpdateRequestImport).search_current(search_params(BulkUpdateRequestImport)).paginate(params[:page], limit: params[:limit])
      respond_with(@imports)
    end

    def show
      authorize(@import)
      respond_with(@import) do |format|
        format.html { redirect_to(bulk_update_request_imports_path(search: { id: @import.id })) }
      end
    end

    def new
      @import = authorize(BulkUpdateRequestImport.new)
      respond_with(@import)
    end

    def edit
      authorize(@import)
    end

    def create
      @import = authorize(BulkUpdateRequestImport.new_with_current(:creator, permitted_attributes(BulkUpdateRequestImport)))
      @import.save!
      @import.queue

      notice("Import queued")
      respond_with(@import)
    rescue ActiveRecord::RecordInvalid, BulkUpdateRequestProcessor::Error, BulkUpdateRequestCommands::ProcessingError => e
      @error = e
      notice("Import failed")
      respond_with(@import) do |format|
        format.html { render(:new, status: :bad_request) }
      end
    end

    # Only reachable for a failed import (BulkUpdateRequestImportPolicy#update?) - edits the
    # script/topic in place and re-queues it via retry!, rather than creating a new record.
    def update
      authorize(@import)
      @import.assign_attributes(permitted_attributes(@import))
      @import.save!
      @import.retry!(CurrentUser.user)

      notice("Import updated and re-queued")
      respond_to do |format|
        format.html { redirect_to(new_bulk_update_request_import_path) }
        format.json
      end
    rescue ActiveRecord::RecordInvalid, BulkUpdateRequestProcessor::Error, BulkUpdateRequestCommands::ProcessingError => e
      @error = e
      notice("Import failed")
      respond_to do |format|
        format.html { render(:edit, status: :bad_request) }
        format.json { render_expected_error(400, e.message) }
      end
    end

    private

    def load_import
      @import = BulkUpdateRequestImport.find(params[:id])
    end
  end
end

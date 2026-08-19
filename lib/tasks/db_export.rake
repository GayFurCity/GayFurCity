# frozen_string_literal: true

namespace(:db_export) do
  desc("Run db export")
  task(create: :environment) do
    DbExportJob.perform_later
  end
end

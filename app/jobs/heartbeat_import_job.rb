class HeartbeatImportJob < ApplicationJob
  queue_as :default

  def perform(import_run_id, file_path)
    HeartbeatImportRunner.run_import(import_run_id:, file_path:)
  end
end

class HeartbeatImportJob < ApplicationJob
  queue_as :default

  def perform(user_id, import_id, file_path)
    HeartbeatImportRunner.run_import(user_id: user_id, import_id: import_id, file_path: file_path)
  end
end

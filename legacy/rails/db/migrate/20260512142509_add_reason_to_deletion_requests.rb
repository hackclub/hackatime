class AddReasonToDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :deletion_requests, :reason, :text, if_not_exists: true
    add_column :deletion_requests, :reason_details, :text, if_not_exists: true
  end
end

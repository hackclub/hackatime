class CreateNotableTables < ActiveRecord::Migration[8.1]
  def change
    create_table :notable_jobs, if_not_exists: true do |t|
      t.datetime :created_at
      t.text :job
      t.string :job_id
      t.text :note
      t.string :note_type
      t.string :queue
      t.float :queued_time
      t.float :runtime
    end

    create_table :notable_requests, if_not_exists: true do |t|
      t.text :action
      t.datetime :created_at
      t.string :ip
      t.text :note
      t.string :note_type
      t.text :params
      t.text :referrer
      t.string :request_id
      t.float :request_time
      t.integer :status
      t.text :url
      t.text :user_agent
      t.references :user, polymorphic: true
    end
  end
end

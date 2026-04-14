class CreateInstanceImportSources < ActiveRecord::Migration[8.1]
  def change
    create_table :instance_import_sources, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :endpoint_url, null: false
      t.string :encrypted_api_key, null: false

      t.timestamps
    end
  end
end

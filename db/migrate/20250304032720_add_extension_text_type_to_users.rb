class AddExtensionTextTypeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hackatime_extension_text_type, :integer, default: 0, null: false
  end
end

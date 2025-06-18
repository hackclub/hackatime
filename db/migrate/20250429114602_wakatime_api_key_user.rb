class WakatimeApiKeyUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :wakatime_api_key, :string, null: true
  end
end

class AddBetaFeaturesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :beta_features, :text, default: '[]'
  end
end

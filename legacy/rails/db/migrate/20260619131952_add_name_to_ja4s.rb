class AddNameToJa4s < ActiveRecord::Migration[8.1]
  def change
    add_column :ja4s, :name, :text, if_not_exists: true
  end
end

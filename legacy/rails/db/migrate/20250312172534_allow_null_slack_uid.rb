class AllowNullSlackUid < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :slack_uid, true
  end
end

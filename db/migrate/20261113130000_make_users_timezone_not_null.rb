class MakeUsersTimezoneNotNull < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  CHECK_NAME = "users_timezone_not_null"

  # Validating a check constraint scans the table without blocking writes, and
  # Postgres then accepts it as proof for SET NOT NULL instead of scanning under
  # an exclusive lock.
  def up
    add_check_constraint :users, "timezone IS NOT NULL", name: CHECK_NAME, validate: false, if_not_exists: true
    validate_check_constraint :users, name: CHECK_NAME
    change_column_null :users, :timezone, false
    remove_check_constraint :users, name: CHECK_NAME
  end

  def down
    change_column_null :users, :timezone, true
  end
end

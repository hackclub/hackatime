class AddRevealedThroughMinuteToDesktopDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :desktop_devices, :revealed_through_minute, :bigint
  end
end

class AddIpAddressToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :ip_address, :inet
  end
end

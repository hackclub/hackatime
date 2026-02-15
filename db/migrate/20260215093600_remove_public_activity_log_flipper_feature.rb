class RemovePublicActivityLogFlipperFeature < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM flipper_gates WHERE feature_key = 'public_activity_log';
      DELETE FROM flipper_features WHERE key = 'public_activity_log';
    SQL
  end

  def down
    # no-op; this feature was intentionally removed
  end
end

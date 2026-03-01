class CreateMailkickSubscriptionsV2 < ActiveRecord::Migration[8.1]
  def change
    create_table :mailkick_subscriptions, if_not_exists: true do |t|
      t.references :subscriber, polymorphic: true, null: false
      t.string :list
      t.timestamps
    end

    unless index_exists?(:mailkick_subscriptions, [ :subscriber_type, :subscriber_id, :list ], name: "index_mailkick_subscriptions_on_subscriber_and_list")
      add_index :mailkick_subscriptions, [ :subscriber_type, :subscriber_id, :list ],
        unique: true, name: "index_mailkick_subscriptions_on_subscriber_and_list"
    end
  end
end

class AddAiTelemetryToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    change_table :heartbeats, bulk: true do |t|
      t.string :ai_model
      t.string :ai_session
      t.string :ai_subscription_plan
      t.bigint :ai_input_tokens
      t.bigint :ai_output_tokens
      t.integer :ai_prompt_length
      t.integer :ai_line_changes
      t.integer :human_line_changes
    end
  end
end

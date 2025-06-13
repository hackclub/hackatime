class AddReturnDataToSignInTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :sign_in_tokens, :return_data, :jsonb
  end
end

class AddContinueParamToSignInTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :sign_in_tokens, :continue_param, :string
  end
end

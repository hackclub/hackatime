class RenameAdminApiKeyBansScopesToPoisons < ActiveRecord::Migration[8.1]
  RENAMES = { "bans:read" => "poisons:read", "bans:write" => "poisons:write" }.freeze

  def up = rename_scopes(RENAMES)
  def down = rename_scopes(RENAMES.invert)

  private

  def rename_scopes(renames)
    renames.each do |from, to|
      execute "UPDATE admin_api_keys SET scopes = array_replace(scopes, #{quote(from)}, #{quote(to)}) WHERE #{quote(from)} = ANY(scopes)"
    end
  end
end

class AddHomepageToRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :homepage, :string
  end
end

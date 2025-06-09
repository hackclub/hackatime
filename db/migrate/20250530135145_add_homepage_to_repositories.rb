class AddHomepageToRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :repositories, :homepage, :string
  end
end

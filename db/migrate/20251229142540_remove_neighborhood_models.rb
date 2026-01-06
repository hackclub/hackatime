class RemoveNeighborhoodModels < ActiveRecord::Migration[8.1]
  def change
    drop_table :neighborhood_apps
    drop_table :neighborhood_posts
    drop_table :neighborhood_projects
    drop_table :neighborhood_ysws_submissions
  end
end

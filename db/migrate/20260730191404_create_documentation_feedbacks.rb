class CreateDocumentationFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :documentation_feedbacks do |t|
      t.references :user, null: true, foreign_key: { on_delete: :cascade }
      t.uuid :visitor_token
      t.boolean :helpful, null: false
      t.string :path, null: false
      t.string :title, null: false

      t.timestamps
    end

    add_index :documentation_feedbacks, [ :user_id, :path ], unique: true,
      where: "user_id IS NOT NULL", name: "index_doc_feedback_on_user_and_path"
    add_index :documentation_feedbacks, [ :visitor_token, :path ], unique: true,
      where: "visitor_token IS NOT NULL", name: "index_doc_feedback_on_visitor_and_path"
    add_check_constraint :documentation_feedbacks,
      "(user_id IS NOT NULL) <> (visitor_token IS NOT NULL)",
      name: "documentation_feedbacks_have_one_identity"
  end
end

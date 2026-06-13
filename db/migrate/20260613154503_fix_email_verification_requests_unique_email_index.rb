class FixEmailVerificationRequestsUniqueEmailIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The old unique index on `email` ignored soft-deletes, so re-adding an
  # email after removing it (which only soft-deletes the request) raised a
  # PG::UniqueViolation. Replace it with a partial unique index that matches
  # the model validation (`uniqueness` scoped to `deleted_at IS NULL`).
  def up
    add_index :email_verification_requests, :email,
              unique: true,
              where: "deleted_at IS NULL",
              name: :index_email_verification_requests_on_email_active,
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :email_verification_requests,
                 name: :index_email_verification_requests_on_email,
                 algorithm: :concurrently,
                 if_exists: true
  end

  def down
    add_index :email_verification_requests, :email,
              unique: true,
              name: :index_email_verification_requests_on_email,
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :email_verification_requests,
                 name: :index_email_verification_requests_on_email_active,
                 algorithm: :concurrently,
                 if_exists: true
  end
end

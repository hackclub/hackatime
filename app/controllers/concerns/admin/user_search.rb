module Admin::UserSearch
  extend ActiveSupport::Concern

  private

  def admin_user_search_results(query_term)
    User.search_identity(query_term)
      .includes(:email_addresses)
      .select(
        "users.*, " \
        "CASE WHEN LOWER(users.username) = #{ActiveRecord::Base.connection.quote(query_term)} " \
        "THEN 0 ELSE 1 END AS exact_match_rank"
      )
      .order(Arel.sql("exact_match_rank ASC, users.username ASC"))
      .limit(20)
  end
end

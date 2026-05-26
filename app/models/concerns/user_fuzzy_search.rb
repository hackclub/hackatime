module UserFuzzySearch
  extend ActiveSupport::Concern

  class_methods do
    # Ranked fuzzy search across id/slack_uid/username/github_username/slack_username/email.
    # Returns a Relation with two virtual attributes per record:
    #
    #   * `rank_score`    — weighted match score: id/slack_uid exact = 1000,
    #                       field exact = 100, prefix = 50, contains = 10
    #   * `matched_email` — the email_addresses row that best matches the query
    #                       (exact > prefix > contains; NULL if the user matched
    #                       on a non-email field).
    #
    # Pass the raw user-supplied term. The method uses ILIKE for case-insensitive
    # matching but compares `users.slack_uid` and the numeric `users.id` lookup
    # case-sensitively, so callers must NOT pre-downcase or mixed-case Slack UIDs
    # miss the 1000-point exact path.
    #
    # Implementation note: the candidate-ID lookup uses UNION over per-column
    # index-using subqueries rather than a flat OR across joined tables, because
    # PG can't `BitmapOr` across tables joined with OR. Each subquery hits its
    # column's gin_trgm_ops index (users.{username,slack_username,github_username},
    # email_addresses.email) or B-tree index (users.slack_uid, users.id) — added
    # in 20260526120000_add_trgm_indexes_for_admin_user_search.rb.
    def fuzzy_ranked_search(term, limit: 20)
      term = term.to_s.strip
      return none if term.blank?

      sanitized = sanitize_sql_like(term)
      numeric_id = (term.match?(/\A\d+\z/) ? term.to_i : nil)
      binds = {
        exact: term,
        ilike_exact: sanitized,
        prefix: "#{sanitized}%",
        contains: "%#{sanitized}%"
      }

      candidate_parts = [
        "SELECT id FROM users WHERE slack_uid = :exact",
        "SELECT id FROM users WHERE username ILIKE :contains",
        "SELECT id FROM users WHERE github_username ILIKE :contains",
        "SELECT id FROM users WHERE slack_username ILIKE :contains",
        "SELECT user_id AS id FROM email_addresses WHERE email ILIKE :contains"
      ]
      candidate_parts << "SELECT id FROM users WHERE id = #{numeric_id}" if numeric_id

      candidates_sql = sanitize_sql_for_conditions([ candidate_parts.join(" UNION "), binds ])

      rank_sql = sanitize_sql_for_conditions([ <<~SQL.squish, binds ])
        CASE WHEN users.id::text = :exact THEN 1000 ELSE 0 END +
        CASE WHEN users.slack_uid = :exact THEN 1000 ELSE 0 END +
        CASE WHEN users.username ILIKE :ilike_exact THEN 100
             WHEN users.username ILIKE :prefix THEN 50
             WHEN users.username ILIKE :contains THEN 10
             ELSE 0 END +
        CASE WHEN users.github_username ILIKE :ilike_exact THEN 100
             WHEN users.github_username ILIKE :prefix THEN 50
             WHEN users.github_username ILIKE :contains THEN 10
             ELSE 0 END +
        CASE WHEN users.slack_username ILIKE :ilike_exact THEN 100
             WHEN users.slack_username ILIKE :prefix THEN 50
             WHEN users.slack_username ILIKE :contains THEN 10
             ELSE 0 END +
        COALESCE(MAX(
          CASE WHEN email_addresses.email ILIKE :ilike_exact THEN 100
               WHEN email_addresses.email ILIKE :prefix THEN 50
               WHEN email_addresses.email ILIKE :contains THEN 10
               ELSE 0 END
        ), 0)
      SQL

      matched_email_sql = sanitize_sql_for_conditions([ <<~SQL.squish, binds ])
        COALESCE(
          MAX(CASE WHEN email_addresses.email ILIKE :ilike_exact THEN email_addresses.email END),
          MAX(CASE WHEN email_addresses.email ILIKE :prefix      THEN email_addresses.email END),
          MAX(CASE WHEN email_addresses.email ILIKE :contains    THEN email_addresses.email END)
        )
      SQL

      left_joins(:email_addresses)
        .select(Arel.sql(
          "users.*, " \
          "(#{rank_sql}) AS rank_score, " \
          "(#{matched_email_sql}) AS matched_email"
        ))
        .where("users.id IN (#{candidates_sql})")
        .group("users.id")
        .order(Arel.sql("rank_score DESC, users.username ASC"))
        .limit(limit)
    end
  end
end

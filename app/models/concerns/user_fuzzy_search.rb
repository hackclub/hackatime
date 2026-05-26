module UserFuzzySearch
  extend ActiveSupport::Concern

  class_methods do
    # Ranked fuzzy search across id/slack_uid/username/github_username/slack_username/email.
    # Returns a Relation with a virtual `rank_score` attribute on each record. Pass the
    # raw user-supplied term — the method downcases internally for case-insensitive LIKE
    # matching but uses the term verbatim for case-sensitive exact comparisons against
    # `users.slack_uid` and `users.id::text`.
    def fuzzy_ranked_search(term, limit: 20)
      term = term.to_s.strip
      return none if term.blank?

      sanitized = sanitize_sql_like(term.downcase)
      binds = {
        exact: term,
        lower: term.downcase,
        prefix: "#{sanitized}%",
        contains: "%#{sanitized}%"
      }

      rank_sql = sanitize_sql_for_conditions([ <<~SQL.squish, binds ])
        CASE WHEN users.id::text = :exact THEN 1000 ELSE 0 END +
        CASE WHEN users.slack_uid = :exact THEN 1000 ELSE 0 END +
        CASE WHEN LOWER(users.username) = :lower THEN 100
             WHEN LOWER(users.username) LIKE :prefix THEN 50
             WHEN LOWER(users.username) LIKE :contains THEN 10
             ELSE 0 END +
        CASE WHEN LOWER(users.github_username) = :lower THEN 100
             WHEN LOWER(users.github_username) LIKE :prefix THEN 50
             WHEN LOWER(users.github_username) LIKE :contains THEN 10
             ELSE 0 END +
        CASE WHEN LOWER(users.slack_username) = :lower THEN 100
             WHEN LOWER(users.slack_username) LIKE :prefix THEN 50
             WHEN LOWER(users.slack_username) LIKE :contains THEN 10
             ELSE 0 END +
        COALESCE(MAX(
          CASE WHEN LOWER(email_addresses.email) = :lower THEN 100
               WHEN LOWER(email_addresses.email) LIKE :prefix THEN 50
               WHEN LOWER(email_addresses.email) LIKE :contains THEN 10
               ELSE 0 END
        ), 0)
      SQL

      left_joins(:email_addresses)
        .select(Arel.sql("users.*, (#{rank_sql}) AS rank_score"))
        .where(
          "users.id::text = :exact OR users.slack_uid = :exact OR " \
          "LOWER(users.username) LIKE :contains OR " \
          "LOWER(users.github_username) LIKE :contains OR " \
          "LOWER(users.slack_username) LIKE :contains OR " \
          "LOWER(email_addresses.email) LIKE :contains",
          binds
        )
        .group("users.id")
        .order(Arel.sql("rank_score DESC, users.username ASC"))
        .limit(limit)
    end
  end
end

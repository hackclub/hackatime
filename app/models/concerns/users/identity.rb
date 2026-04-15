module Users
  module Identity
    extend ActiveSupport::Concern

    included do
      scope :search_identity, ->(term) {
        term = term.to_s.strip.downcase
        return none if term.blank?

        pattern = "%#{sanitize_sql_like(term)}%"

        left_joins(:email_addresses)
          .where(
            "LOWER(users.username) LIKE :p OR " \
            "LOWER(users.slack_username) LIKE :p OR " \
            "LOWER(users.github_username) LIKE :p OR " \
            "LOWER(email_addresses.email) LIKE :p OR " \
            "CAST(users.id AS TEXT) LIKE :p",
            p: pattern
          )
          .distinct
      }
    end

    class_methods do
      # Look up a user by numeric ID, slack_uid, hca_id, or username
      def lookup_by_identifier(id)
        return nil if id.blank?

        numeric_id = id.to_i if id.match?(/^\d+$/)

        relation = where(slack_uid: id)
          .or(where(hca_id: id))
          .or(where(username: id))
        relation = where(id: numeric_id).or(relation) if numeric_id

        candidates = relation.to_a

        if numeric_id
          match = candidates.find { |u| u.id == numeric_id }
          return match if match
        end

        candidates.find { |u| u.slack_uid == id } ||
          candidates.find { |u| u.hca_id == id } ||
          candidates.find { |u| u.username == id }
      end

      def not_convicted
        where.not(trust_level: trust_levels[:red])
      end

      def not_suspect
        where(trust_level: [ trust_levels[:blue], trust_levels[:green] ])
      end

      if Rails.env.development?
        def slow_find_by_email(email)
          EmailAddress.find_by(email: email)&.user
        end
      end
    end

    private

    def normalize_username
      original = username
      @username_cleared_for_invisible = false

      return if original.nil?

      cleaned = original.gsub(/\p{Cf}/, "")
      stripped = cleaned.strip

      if stripped.empty?
        self.username = nil
        @username_cleared_for_invisible = original.length.positive?
      else
        self.username = stripped
      end
    end

    def username_must_be_visible
      if instance_variable_defined?(:@username_cleared_for_invisible) && @username_cleared_for_invisible
        errors.add(:username, "must include visible characters")
      end
    end
  end
end

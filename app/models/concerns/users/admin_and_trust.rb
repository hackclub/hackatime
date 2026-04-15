module Users
  module AdminAndTrust
    extend ActiveSupport::Concern

    included do
      enum :trust_level, {
        blue: 0,
        red: 1,
        green: 2,
        yellow: 3
      }

      enum :admin_level, {
        default: 0,
        superadmin: 1,
        admin: 2,
        viewer: 3,
        ultraadmin: 4
      }, prefix: :admin_level
    end

    class_methods do
      def not_convicted
        where.not(trust_level: trust_levels[:red])
      end

      def not_suspect
        where(trust_level: [ trust_levels[:blue], trust_levels[:green] ])
      end
    end

    def can_convict_users?
      admin_level_superadmin? || admin_level_ultraadmin?
    end

    def set_admin_level(level)
      return false unless level.present? && self.class.admin_levels.key?(level)

      previous_level = admin_level

      if previous_level != level.to_s
        update!(admin_level: level.to_s)
      end

      true
    end

    def set_trust(level, changed_by_user: nil, reason: nil, notes: nil)
      return false unless level.present?

      previous_level = trust_level

      if changed_by_user.present? && level.to_s == "red" && !changed_by_user.can_convict_users?
        return false
      end

      if previous_level != level.to_s
        if changed_by_user.present?
          trust_level_audit_logs.create!(
            changed_by: changed_by_user,
            previous_trust_level: previous_level,
            new_trust_level: level.to_s,
            reason: reason,
            notes: notes
          )
        end

        update!(trust_level: level)
      end

      true
    end

    def active_deletion_request
      deletion_requests.active.order(created_at: :desc).first
    end

    def pending_deletion?
      active_deletion_request.present?
    end

    def can_request_deletion?
      return false if pending_deletion?
      return true unless red?

      last_audit = trust_level_audit_logs.where(new_trust_level: :red).order(created_at: :desc).first
      return true unless last_audit

      last_audit.created_at <= 365.days.ago
    end
  end
end

# frozen_string_literal: true

# Case-insensitive filtering for heartbeat fields where display names differ from raw DB values.
module HeartbeatFilterConcern
  extend ActiveSupport::Concern

  private

  CASE_INSENSITIVE_FIELDS = %i[language editor operating_system].freeze

  def apply_heartbeat_filter(scope, field, val, user: nil)
    return scope if val.blank?
    vals = Array(val)
    CASE_INSENSITIVE_FIELDS.include?(field) ? case_insensitive_filter(scope, field, vals, user) : scope.where(field => vals)
  end

  def case_insensitive_filter(scope, field, vals, user)
    raw = (user ? user.heartbeats : scope).distinct.pluck(field).compact_blank
    matches = raw.select { |r| vals.any? { |v| v.casecmp?(r) || v.casecmp?(display_name(field, r)) } }
    matches.any? ? scope.where(field => matches) : scope.none
  end

  def display_name(field, val)
    h = ApplicationController.helpers
    case field
    when :language then WakatimeService.categorize_language(val) || val
    when :editor then h.display_editor_name(val)
    when :operating_system then h.display_os_name(val)
    else val
    end
  end

  def apply_heartbeat_filters(scope, filters, user: nil)
    filters.each { |f, v| scope = apply_heartbeat_filter(scope, f, v, user: user) }
    scope
  end
end

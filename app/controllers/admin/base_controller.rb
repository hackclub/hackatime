class Admin::BaseController < ApplicationController
  # Each subclass declares which Pundit record it authorizes against by
  # setting `authorization_record`, then adds:
  #
  #   before_action :authorize_admin_action!
  #
  # *after* its `set_*` before_actions so the record is populated. The
  # default `authorization_record` is `:admin` (gating via
  # `AdminPolicy#<action>?`).
  #
  # Examples:
  #   self.authorization_record = TrustLevelAuditLog
  #   self.authorization_record = ->(c) { c.instance_variable_get(:@deletion_request) || DeletionRequest }
  #
  # Subclasses can also override `authorize_action` if the predicate
  # name doesn't match `action_name`.
  class_attribute :authorization_record, instance_accessor: false, default: :admin

  private

  def authorize_admin_action!
    authorize(authorization_record_for, authorize_action)
  rescue Pundit::NotAuthorizedError
    redirect_to root_path, alert: "You are not authorized to access this page."
  end

  def authorization_record_for
    record = self.class.authorization_record
    record.respond_to?(:call) ? record.call(self) : record
  end

  # Maps `action_name` to a Pundit predicate symbol. Override in
  # subclasses if your action name doesn't match the policy method.
  def authorize_action
    "#{action_name}?".to_sym
  end
end

class Admin::BaseController < ApplicationController
  # Authorization is opt-OUT: every admin controller automatically goes
  # through `authorize_admin_action!`. Subclasses customize behavior via
  # the `authorization_record` class attribute (default: `:admin`, which
  # gates through `AdminPolicy#<action>?`).
  #
  # Examples:
  #   self.authorization_record = TrustLevelAuditLog
  #   self.authorization_record = ->(c) { c.instance_variable_get(:@deletion_request) || DeletionRequest }
  #
  # If `authorization_record` is a lambda that depends on an instance
  # variable set by another `before_action` (e.g. `set_application`),
  # the subclass must declare that loader with `prepend_before_action`
  # so it runs before this base callback. Skipping authorization for
  # specific actions is allowed via `skip_before_action` (see
  # `AdminUsersController#update`, which authorizes inline because the
  # policy depends on the target user).
  #
  # Subclasses can also override `authorize_action` if the predicate
  # name doesn't match `action_name`.
  class_attribute :authorization_record, instance_accessor: false, default: :admin

  before_action :authorize_admin_action!

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

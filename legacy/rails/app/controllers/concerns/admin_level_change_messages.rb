# frozen_string_literal: true

# Shared denial-reason messages for admin_level change attempts.
#
# Used by both the web `Admin::AdminUsersController` and the API
# `Api::Admin::V1::PermissionsController` so the two stay in sync. The
# authorization rules themselves live on `User#can_change_admin_level_of?`;
# this concern only translates a denied decision into a user-facing message.
module AdminLevelChangeMessages
  extend ActiveSupport::Concern

  private

  # Returns a human-readable reason that `current_user` cannot change
  # `target_user`'s admin_level to `new_level`. Mirrors the rule order in
  # `User#can_change_admin_level_of?` so the most specific reason wins.
  def admin_level_change_denial_message(target_user, new_level)
    if target_user == current_user
      "You cannot change your own admin level."
    elsif new_level.to_s == "ultraadmin" && current_user.admin_level != "ultraadmin"
      "Only ultraadmins can grant the ultraadmin role."
    elsif target_user.admin_level == "ultraadmin"
      "Only ultraadmins can change an ultraadmin's role."
    else
      "You are not authorized to change this user's admin level."
    end
  end
end

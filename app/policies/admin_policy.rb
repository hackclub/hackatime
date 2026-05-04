# frozen_string_literal: true

# AdminPolicy is a "headless" policy used to gate access to the admin
# area as a whole, plus a few cross-cutting flags (e.g. the Mini Profiler).
#
# Resource-specific decisions live on their own policies (UserPolicy,
# DeletionRequestPolicy, etc).
#
# Use:
#   authorize :admin, :access?
#   policy(:admin).admin?
class AdminPolicy < ApplicationPolicy
  # Anyone in the admin chain (viewer/admin/superadmin/ultraadmin) can
  # reach the admin area. Per-page policies tighten this further.
  def access?
    any_admin?
  end

  # Mini Profiler is a developer/perf tool. Limit to admin and above so
  # read-only viewers don't get a perf overlay they can't act on.
  def mini_profiler?
    admin?
  end
end

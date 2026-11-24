class Admin::AuditSubmissionsController < Admin::BaseController
  before_action -> { require_admin_level!(:admin, :superadmin) }, only: [ :update ]

  # GET /admin/audit_submissions
  def index
    submissions = AuditSubmission.includes(:user).order(created_at: :desc).limit(100).map do |sub|
      {
        id: sub.id,
        username: sub.user.username.presence || "user-#{sub.user_id}",
        project_name: sub.project_name.presence || "project-#{sub.project_hash.first(8)}",
        program_slug: sub.program_slug,
        submitted_hours: sub.submitted_hours.to_f.round(2),
        approved_hours: sub.approved_hours&.to_f&.round(2),
        chain_verified: sub.chain_verified,
        git_push_verified: sub.git_push_verified,
        plugin_share_pct: sub.plugin_share_pct.to_f.round(1),
        anomaly_count: Array(sub.anomaly_flags).size,
        review_status: sub.review_status,
        created_at: sub.created_at.iso8601
      }
    end

    render inertia: "Admin/AuditSubmissions/Index", props: {
      page_title: "Fraud Squad Audit Workbench | Hackatime Admin",
      submissions: submissions
    }
  end

  # GET /admin/audit_submissions/:id
  def show
    sub = AuditSubmission.includes(:user).find(params[:id])
    windows = sub.project_windows.limit(1000).map do |w|
      {
        id: w.id,
        window_start: w.window_start.iso8601,
        raw_seconds: w.raw_seconds,
        credited_seconds: w.credited_seconds,
        convertible_seconds: w.convertible_seconds,
        converted: w.converted?,
        struggle_points: w.struggle_points.to_f.round(2),
        effective_multiplier: w.effective_multiplier.to_f.round(3),
        provenance_mask: w.provenance_mask,
        persisted_diff_lines: w.persisted_diff_lines,
        ai_harness: w.ai_harness,
        signal_counts: w.signal_counts || {},
        git_head_sha: w.git_head_sha
      }
    end

    event_scope = StrugglePointEvent.where(user_id: sub.user_id, project_hash: sub.project_hash)
    sp_breakdown = StrugglePointEvent.signal_breakdown_summary(event_scope)
    point_events = event_scope.order(window_start: :desc, id: :desc).limit(100).map do |ev|
      {
        id: ev.id,
        window_start: ev.window_start.iso8601,
        signal_code: ev.signal_code,
        signal_label: ev.signal_label,
        trigger_count: ev.trigger_count,
        raw_points: ev.raw_points.to_f.round(2),
        awarded_points: ev.awarded_points.to_f.round(2),
        provenance_tier: ev.provenance_tier,
        persisted_diff_lines: ev.persisted_diff_lines,
        gate_status: ev.gate_status,
        gate_label: ev.gate_label
      }
    end

    render inertia: "Admin/AuditSubmissions/Show", props: {
      page_title: "Audit ##{sub.id} · Fraud Squad Workbench",
      submission: {
        id: sub.id,
        username: sub.user.username.presence || "user-#{sub.user_id}",
        project_name: sub.project_name.presence || "project-#{sub.project_hash.first(8)}",
        project_hash: sub.project_hash,
        program_slug: sub.program_slug,
        git_remote_url: sub.git_remote_url,
        bundle_sha256: sub.bundle_sha256,
        submitted_hours: sub.submitted_hours.to_f.round(2),
        approved_hours: sub.approved_hours&.to_f&.round(2),
        chain_verified: sub.chain_verified,
        git_push_verified: sub.git_push_verified,
        plugin_share_pct: sub.plugin_share_pct.to_f.round(1),
        sampled_randomly: sub.sampled_randomly,
        sampling_reason: sub.sampling_reason,
        anomaly_flags: Array(sub.anomaly_flags),
        review_status: sub.review_status,
        reviewer_notes: sub.reviewer_notes
      },
      windows: windows,
      sp_breakdown: sp_breakdown,
      point_events: point_events
    }
  end

  # PATCH /admin/audit_submissions/:id
  def update
    sub = AuditSubmission.find(params[:id])
    status = params[:review_status].to_s
    unless AuditSubmission::REVIEW_STATUSES.include?(status)
      return redirect_back fallback_location: admin_audit_submission_path(sub), alert: "Invalid review status."
    end

    sub.update!(
      review_status: status,
      approved_hours: params[:approved_hours].presence&.to_d,
      reviewer_notes: params[:reviewer_notes].to_s,
      reviewed_by: current_user,
      reviewed_at: Time.current
    )

    redirect_to admin_audit_submission_path(sub), notice: "Audit ##{sub.id} marked #{status}."
  end
end

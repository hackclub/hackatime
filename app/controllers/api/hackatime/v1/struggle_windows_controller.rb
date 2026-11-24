class Api::Hackatime::V1::StruggleWindowsController < ApplicationController
  before_action :set_user
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_lockout
  before_action :check_lockout

  MAX_BATCH_SIZE = 100

  WINDOW_KEYS = %i[
    user_id project_hash project_name window_start_unix
    raw_seconds credited_seconds struggle_points
    diversity_multiplier verify_multiplier effective_multiplier
    effective_multiplier_milli provenance_mask persisted_diff_lines
    primary_language ai_harness git_head_sha
    prev_chain_hash server_nonce chain_hash_hex ed25519_sig_hex
  ].freeze

  # PUT /api/hackatime/v1/users/:id/ed25519_key
  def update_public_key
    raw_key = StruggleChainVerifier.decode_hex_exact(
      params[:ed25519_public_key_hex].to_s,
      StruggleChainVerifier::ED25519_PUBLIC_KEY_BYTES
    )
    unless raw_key && StruggleChainVerifier.valid_public_key?(raw_key)
      return render_bad_request("invalid ed25519_public_key_hex")
    end

    @user.update!(ed25519_public_key: raw_key)
    render json: { updated: true }, status: :ok
  end

  # GET /api/hackatime/v1/users/:id/struggle_nonce
  def nonce
    issued = StruggleNonceStore.issue(user_id: @user.id)
    render json: {
      server_nonce: issued,
      user_id: @user.id.to_s,
      expires_in_seconds: StruggleNonceStore::DEFAULT_TTL.to_i
    }, status: :ok
  end

  # POST /api/hackatime/v1/users/:id/struggle_windows
  def create
    unless @user.ed25519_public_key.present?
      return render_bad_request("user has no registered Ed25519 public key")
    end

    windows = extract_window_payloads
    return render_bad_request("empty window payload") if windows.empty?
    if windows.size > MAX_BATCH_SIZE
      return render_bad_request("too many struggle windows in a single request (max #{MAX_BATCH_SIZE})")
    end

    chain_tips = {}
    persisted_anchors = {}
    rejection_error = nil

    ActiveRecord::Base.transaction do
      windows.each do |raw_item|
        item = permit_window(raw_item)
        claimed_user_id = item[:user_id].presence || @user.id.to_s
        unless claimed_user_id == @user.id.to_s
          rejection_error = "user_id mismatch with API key"
          raise ActiveRecord::Rollback
        end

        project_hash = item[:project_hash].to_s
        unless persisted_anchors.key?(project_hash)
          anchor_row = @user.struggle_windows
                            .where(project_hash: project_hash)
                            .order(window_start: :desc)
                            .first
          persisted_anchors[project_hash] = anchor_row
          chain_tips[project_hash] = anchor_row&.chain_hash || StruggleWindow::GENESIS_CHAIN_HASH
        end
        expected_prev = chain_tips[project_hash]

        nonce_ok = StruggleNonceStore.valid?(user_id: @user.id, nonce: item[:server_nonce].to_s)
        unless nonce_ok
          # Offline resilience across up to 7 days / server cache restarts:
          # Allow a cryptographically chained continuation from an ALREADY-persisted DB window
          # when the timestamp is within [7 days ago, now + 10 min] and strictly newer than anchor.
          anchor = persisted_anchors[project_hash]
          win_time = Time.at(item[:window_start_unix].to_i).utc
          nonce_str = item[:server_nonce].to_s
          offline_anchored = anchor.present? &&
                             nonce_str.match?(/\A[0-9a-f]{32}\z/) &&
                             win_time > anchor.window_start &&
                             win_time >= 7.days.ago &&
                             win_time <= 10.minutes.from_now
          unless offline_anchored
            rejection_error = "invalid or expired server_nonce (possible backdating)"
            raise ActiveRecord::Rollback
          end
        end

        valid = StruggleChainVerifier.valid?(
          window_params: item.merge(user_id: claimed_user_id),
          expected_prev_chain_hash: expected_prev,
          raw_public_key: @user.ed25519_public_key
        )
        unless valid
          rejection_error = "hash-chain linkage or Ed25519 signature verification failed"
          raise ActiveRecord::Rollback
        end

        sig_bytes = StruggleChainVerifier.decode_hex_exact(
          item[:ed25519_sig_hex].to_s,
          StruggleChainVerifier::ED25519_SIGNATURE_BYTES
        )

        record = @user.struggle_windows.find_or_initialize_by(
          project_hash: project_hash,
          window_start: Time.at(item[:window_start_unix].to_i).utc
        )
        # Option A: windows ingest as unconverted SP (`credited_seconds` stays 0 until user converts on /my/struggle)
        attrs = {
          project_name: item[:project_name].presence || record.project_name,
          raw_seconds: item[:raw_seconds].to_i,
          convertible_seconds: item[:credited_seconds].to_i,
          struggle_points: item[:struggle_points].to_d,
          diversity_multiplier: item[:diversity_multiplier].to_d,
          verify_multiplier: (item[:verify_multiplier].presence || 1.0).to_d,
          effective_multiplier: item[:effective_multiplier].to_d,
          effective_multiplier_milli: item[:effective_multiplier_milli].to_i,
          provenance_mask: (item[:provenance_mask].presence || 1).to_i,
          persisted_diff_lines: [ item[:persisted_diff_lines].to_i, 0 ].max,
          anomaly_flags: normalized_anomaly_flags(item[:anomaly_flags]),
          primary_language: item[:primary_language].presence,
          ai_harness: item[:ai_harness].presence || "none",
          signal_counts: normalized_signal_counts(item[:signal_counts]),
          git_head_sha: item[:git_head_sha].presence,
          prev_chain_hash: item[:prev_chain_hash].to_s,
          server_nonce: item[:server_nonce].to_s,
          chain_hash: item[:chain_hash_hex].to_s,
          signature: sig_bytes
        }
        attrs[:credited_seconds] = 0 unless record.converted?
        record.assign_attributes(attrs)
        record.save!
        sync_point_events!(record, item[:signal_breakdown])

        chain_tips[project_hash] = record.chain_hash
      end
    end

    return render_forbidden(rejection_error) if rejection_error.present?

    next_nonce = StruggleNonceStore.issue(user_id: @user.id)
    render json: {
      accepted: windows.size,
      next_server_nonce: next_nonce
    }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_bad_request(e.record.errors.full_messages.to_sentence)
  end

  # POST /api/hackatime/v1/users/:id/audit_submissions
  def submit_audit
    submission = @user.audit_submissions.create!(
      project_hash: params.require(:project_hash).to_s,
      project_name: params[:project_name].presence,
      program_slug: params.require(:program_slug).to_s,
      git_remote_url: params[:git_remote_url].presence,
      bundle_sha256: params.require(:bundle_sha256).to_s,
      submitted_hours: params.require(:submitted_hours).to_d
    )
    submission.bundle_file.attach(params[:bundle_file]) if params[:bundle_file].present?

    VerifyAuditSubmissionJob.perform_later(submission.id)

    render json: {
      id: submission.id,
      review_status: submission.review_status
    }, status: :created
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render_bad_request(e.message)
  end

  private

  def set_user
    @user = api_user_from_credentials(
      api_key_sources: %i[bearer basic query],
      allow_restricted: true
    )
    render_unauthorized unless @user
  end

  def check_lockout = (render_forbidden("Account pending deletion") if @user&.pending_deletion?)

  def extract_window_payloads
    if params[:_json].is_a?(Array)
      params[:_json]
    elsif params[:struggle_windows].is_a?(Array)
      params[:struggle_windows]
    elsif params[:project_hash].present?
      [ params ]
    else
      []
    end
  end

  def permit_window(value)
    p = case value
    when ActionController::Parameters then value
    when Hash then ActionController::Parameters.new(value)
    else ActionController::Parameters.new
    end
    p.permit(
      *WINDOW_KEYS,
      signal_counts: {},
      anomaly_flags: [],
      signal_breakdown: %i[signal_code trigger_count raw_points awarded_points provenance_mask gate_status]
    ).to_h.symbolize_keys
  end

  def normalized_signal_counts(raw)
    return {} unless raw.is_a?(Hash)

    raw.each_with_object({}) do |(k, v), acc|
      acc[k.to_s] = v.to_i if k.to_s.start_with?("SIG_") && v.to_i > 0
    end
  end

  def normalized_anomaly_flags(raw)
    return [] unless raw.is_a?(Array)

    raw.filter_map { |f| f.to_s.strip.presence }.uniq.first(16)
  end

  def sync_point_events!(window_record, breakdown)
    entries = Array(breakdown).select { |e| e.is_a?(Hash) }
    if entries.empty?
      # Graceful fallback when older clients emit signal_counts without signal_breakdown
      counts = window_record.signal_counts || {}
      total_triggers = counts.values.sum.to_f
      entries = counts.map do |code, cnt|
        share = total_triggers > 0 ? (window_record.struggle_points.to_f * (cnt.to_f / total_triggers)).round(2) : 0.0
        {
          "signal_code" => code,
          "trigger_count" => cnt.to_i,
          "raw_points" => share,
          "awarded_points" => share,
          "provenance_mask" => window_record.provenance_mask,
          "gate_status" => "awarded"
        }
      end
    end

    entries.each do |raw_entry|
      entry = raw_entry.stringify_keys
      code = entry["signal_code"].to_s
      next unless StrugglePointEvent::SIGNAL_LABELS.key?(code)

      ev = window_record.struggle_point_events.find_or_initialize_by(signal_code: code)
      ev.assign_attributes(
        user_id: window_record.user_id,
        project_hash: window_record.project_hash,
        project_name: window_record.project_name,
        window_start: window_record.window_start,
        trigger_count: [ entry["trigger_count"].to_i, 1 ].max,
        raw_points: [ entry["raw_points"].to_d, 0.to_d ].max,
        awarded_points: [ entry["awarded_points"].to_d, 0.to_d ].max,
        provenance_tier: StrugglePointEvent.tier_from_mask(entry["provenance_mask"] || window_record.provenance_mask),
        persisted_diff_lines: window_record.persisted_diff_lines,
        git_head_sha: window_record.git_head_sha,
        gate_status: entry["gate_status"].to_s.presence || "awarded"
      )
      ev.save!
    end
  end
end

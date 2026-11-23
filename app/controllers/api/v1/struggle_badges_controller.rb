require "cgi"

class Api::V1::StruggleBadgesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_lockout

  # GET /api/v1/struggle_badge/:username.svg
  def show
    user = User.lookup_by_identifier(params[:username])
    return head :not_found unless user&.allow_public_stats_lookup

    windows = user.struggle_windows.converted
    total_sec = windows.sum(:credited_seconds).to_i
    win_count = windows.count
    avg_mult = win_count > 0 ? windows.average(:effective_multiplier).to_f : 0.0

    bug_squashes = 0
    steering = 0
    lang_totals = Hash.new(0)
    windows.pluck(:credited_seconds, :primary_language, :signal_counts).each do |sec, lang, sigs|
      lang_totals[lang] += sec if lang.present?
      next unless sigs.is_a?(Hash)

      bug_squashes += sigs["SIG_ERROR_LOOP"].to_i
      steering += sigs["SIG_ARCH_STEER"].to_i + sigs["SIG_VISUAL_GUIDE"].to_i +
                  sigs["SIG_DIFF_SURGERY"].to_i + sigs["SIG_MANUAL_CODE"].to_i
    end

    arch_score = if win_count > 0
      steering_ratio = [ 1.0, steering.to_f / (win_count * 2.0) ].min
      ((avg_mult * 65.0) + (steering_ratio * 35.0)).round.clamp(0, 100)
    else
      0
    end

    archetype = if bug_squashes >= 10
      "Relentless Debugger"
    elsif arch_score >= 80
      "Systems Architect"
    elsif avg_mult >= 0.90 && win_count >= 6
      "Craftsman"
    elsif win_count >= 12
      "Ship Machine"
    else
      "Systems Builder"
    end

    top_lang = lang_totals.max_by { |_, v| v }&.first || "Code"
    hours_str = format("%.1fh", total_sec / 3600.0)
    mult_str = format("%.2fx", avg_mult)
    bar_width = (arch_score * 168) / 100

    handle = CGI.escapeHTML("@#{user.username.presence || user.id}")
    safe_arch = CGI.escapeHTML(archetype)
    safe_lang = CGI.escapeHTML(top_lang)

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="460" height="148" viewBox="0 0 460 148" role="img" aria-label="Hackatime AI Struggle Card">
        <defs>
          <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#0d1117"/>
            <stop offset="100%" stop-color="#161b22"/>
          </linearGradient>
          <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#ec3750"/>
            <stop offset="100%" stop-color="#ff8c37"/>
          </linearGradient>
        </defs>
        <rect width="460" height="148" rx="12" fill="url(#bg)" stroke="#30363d" stroke-width="1.5"/>
        <rect x="0" y="0" width="460" height="4" rx="2" fill="url(#accent)"/>
        <text x="20" y="32" fill="#f0f6fc" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="15" font-weight="700">HACKATIME AI // #{handle}</text>
        <rect x="306" y="16" width="134" height="22" rx="11" fill="#21262d" stroke="#ec3750" stroke-width="1"/>
        <text x="373" y="31" text-anchor="middle" fill="#ff8c37" font-family="ui-sans-serif,system-ui,sans-serif" font-size="11" font-weight="600">#{safe_arch}</text>
        <text x="20" y="64" fill="#8b949e" font-family="ui-sans-serif,system-ui,sans-serif" font-size="11">VERIFIED STRUGGLE</text>
        <text x="20" y="88" fill="#58a6ff" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="22" font-weight="700">#{hours_str}</text>
        <text x="148" y="64" fill="#8b949e" font-family="ui-sans-serif,system-ui,sans-serif" font-size="11">AVG MULTIPLIER</text>
        <text x="148" y="88" fill="#3fb950" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="22" font-weight="700">#{mult_str}</text>
        <text x="272" y="64" fill="#8b949e" font-family="ui-sans-serif,system-ui,sans-serif" font-size="11">ARCHITECT SCORE</text>
        <text x="440" y="64" text-anchor="end" fill="#f0f6fc" font-family="ui-monospace,SFMono-Regular,Menlo,monospace" font-size="12" font-weight="700">#{arch_score}/100</text>
        <rect x="272" y="74" width="168" height="10" rx="5" fill="#21262d"/>
        <rect x="272" y="74" width="#{bar_width}" height="10" rx="5" fill="url(#accent)"/>
        <line x1="20" y1="108" x2="440" y2="108" stroke="#21262d" stroke-width="1"/>
        <text x="20" y="130" fill="#8b949e" font-family="ui-sans-serif,system-ui,sans-serif" font-size="12">Top Stack: <tspan fill="#f0f6fc" font-weight="600">#{safe_lang}</tspan>  |  Bugs Squashed: <tspan fill="#f0f6fc" font-weight="600">#{bug_squashes}</tspan>  |  Verified Ed25519 Chain</text>
      </svg>
    SVG

    expires_in 5.minutes, public: true
    response.headers["X-Content-Type-Options"] = "nosniff"
    render plain: svg, content_type: "image/svg+xml; charset=utf-8"
  end
end

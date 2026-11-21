module Api
  module V1
    module Authenticated
      # Backs the Hackatime Desktop companion site (desktop/site). Everything
      # here is the signed-in student's own view: devices, what they shipped,
      # their reviewer conversation and who looked at their timelapse. Flags,
      # confidence and scoring internals are reviewer-only and never returned.
      class DesktopController < ApplicationController
        require_oauth_scope :desktop
        before_action :ensure_desktop_application!

        rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: "Not found" }, status: :not_found }
        rescue_from ActionController::ParameterMissing, with: -> { render json: { error: "Something was missing from that form. Try again." }, status: :bad_request }

        def index
          devices = current_user.desktop_devices.active.order(:created_at)
          ships = current_user.evidence_ships.where.not(status: :draft).order(created_at: :desc).limit(50)
          render json: {
            user: user_json,
            today_seconds: Time.use_zone(current_user.timezone) { desktop_heartbeats.today.duration_seconds },
            stats: stats_json,
            devices: devices.map { |device| device_json(device) },
            ships: ships.map { |ship| ship_row(ship) }
          }
        end

        def show_ship
          ship = current_user.evidence_ships.where.not(status: :draft).find(params[:id])
          blocks = ship.blocks
          first, last = blocks.first, blocks.last
          render json: ship_row(ship).merge(
            reflection: Evidence::Summary.reflection(ship),
            started_at: first && Time.at(first.captured_at_ms / 1000).utc.iso8601,
            ended_at: last && Time.at(last.captured_at_ms / 1000).utc.iso8601,
            frames_shared: ship.evidence_frames.count,
            reviewer_question: ship.reviewer_question, user_answer: ship.user_answer,
            decision_reason: ship.decision_reason, appeal: ship.appeal, appealable: ship.appealable?,
            access_log: ship.evidence_views.includes(:viewer).order(created_at: :desc).limit(100).map { |view|
              viewer = view.viewer
              { at: view.created_at.iso8601, who: viewer&.display_name || "A reviewer who has since left", avatar_url: viewer&.avatar_url,
                admin: viewer&.admin_level.in?(%w[admin superadmin ultraadmin]) || false, what: view_label(view.action) }
            }
          )
        end

        # The desktop app opens the site with a PKCE challenge; the student
        # consents to timelapse capture and gets a one-time pairing code.
        def create_pairing
          _pairing, code = DesktopPairing.issue!(user: current_user, code_challenge: params.require(:code_challenge).to_s,
            consented: ActiveModel::Type::Boolean.new.cast(params[:consent]))
          render json: { code:, deep_link: "hackatime-desktop://pair?code=#{code}", expires_at: DesktopPairing::TTL.from_now.iso8601 }, status: :created
        rescue ArgumentError
          render json: { error: "Agree to the timelapse to pair this Mac." }, status: :unprocessable_entity
        rescue ActiveRecord::RecordInvalid
          render json: { error: "This pairing link is incomplete. Start pairing again from the app." }, status: :unprocessable_entity
        end

        def revoke_device
          current_user.desktop_devices.active.find(params[:id]).revoke!
          head :no_content
        end

        def answer
          ship = current_user.evidence_ships.needs_info.find(params[:id])
          ship.update!(user_answer: params.require(:answer).to_s.strip.first(5_000), status: :submitted)
          render json: ship_row(ship)
        end

        def appeal
          ship = current_user.evidence_ships.find(params[:id])
          return render(json: { error: "This decision can no longer be appealed" }, status: :unprocessable_entity) unless ship.appealable?

          ship.update!(appeal: params.require(:appeal).to_s.strip.first(5_000), status: :appealed, reviewer: nil)
          render json: ship_row(ship)
        end

        private

        # The scope alone is not enough: tokens from applications that are
        # not, or are no longer, verified for it cannot pair or manage devices.
        def ensure_desktop_application!
          render json: { error: "This application cannot manage Hackatime Desktop" }, status: :forbidden unless doorkeeper_token.application&.desktop_scope_allowed?
        end

        def desktop_heartbeats = current_user.heartbeats.where(entity: "Hackatime Desktop")

        # The student's own numbers: time per day for the last two weeks, top
        # projects this week, how much of their code was theirs and what got approved.
        def stats_json
          Time.use_zone(current_user.timezone) do
            start = 13.days.ago.beginning_of_day
            recent = desktop_heartbeats.where(time: start.to_i..)
            zone = ActiveRecord::Base.connection.quote(Time.zone.tzinfo.name)
            # One grouped query: "YYYY-MM-DD|project" => seconds.
            by_day_project = recent.group(Arel.sql("to_char(to_timestamp(time) AT TIME ZONE #{zone}, 'YYYY-MM-DD') || '|' || COALESCE(project, '')")).duration_seconds
            by_day = Hash.new { |hash, day| hash[day] = {} }
            by_day_project.each { |key, seconds| day, project = key.split("|", 2); by_day[day][project] = seconds }
            week = recent.where(time: 6.days.ago.beginning_of_day.to_i..)
            lines = week.pick(Arel.sql("COALESCE(SUM(human_line_changes), 0)"), Arel.sql("COALESCE(SUM(ai_line_changes), 0)"))
            {
              days: (0..13).map do |i|
                day = (start + i.days).to_date.iso8601
                projects = by_day.fetch(day, {}).sort_by { |_, seconds| -seconds }.map { |project, seconds| { project:, seconds: } }
                { date: day, seconds: projects.sum { |entry| entry[:seconds] }, projects: }
              end,
              week_seconds: week.duration_seconds,
              projects: week.group(:project).duration_seconds.sort_by { |_, seconds| -seconds }.first(5).map { |project, seconds| { project:, seconds: } },
              human_lines: lines[0].to_i, ai_lines: lines[1].to_i,
              approved_seconds: current_user.evidence_ships.where(status: %i[approved deflated]).sum(:approved_seconds)
            }
          end
        end

        def user_json
          theme = User.theme_metadata(current_user.theme)
          { name: current_user.display_name, username: current_user.username, avatar_url: current_user.avatar_url,
            timezone: current_user.timezone,
            theme: { value: theme[:value], label: theme[:label], color_scheme: theme[:color_scheme],
                     palette: theme[:preview].merge(border: theme.dig(:docs, :border), muted: theme.dig(:docs, :muted_foreground)) } }
        end

        def device_json(device)
          { id: device.id, name: device.name, platform: device.platform, app_version: device.app_version,
            hardware_key: !device.key_software?, paired_at: device.created_at.iso8601, last_seen_at: device.last_seen_at&.iso8601 }
        end

        # Student-facing status: a pending review is just "in review".
        def ship_row(ship)
          { id: ship.id, project: ship.project, status: public_status(ship), submitted_at: ship.submitted_at&.iso8601,
            claimed_seconds: ship.claimed_seconds, approved_seconds: ship.approved_seconds,
            decided_at: ship.decided_at&.iso8601 }
        end

        def public_status(ship)
          case ship.status
          when "submitted", "appealed" then ship.appeal.present? ? "appeal_in_review" : "in_review"
          when "needs_info" then "question"
          when "deflated" then "approved_in_part"
          else ship.status
          end
        end

        def view_label(action)
          case action
          when "open" then "opened your ship"
          when "frame" then "watched a timelapse frame"
          when /\Adecide/ then "made a decision"
          else "looked at your ship"
          end
        end
      end
    end
  end
end

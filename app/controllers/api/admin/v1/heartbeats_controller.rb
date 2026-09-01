module Api
  module Admin
    module V1
      class HeartbeatsController < Api::Admin::V1::ApplicationController
        include DateParsing

        MAX_LIMIT = 10_000
        DEFAULT_LIMIT = 1_000
        HEARTBEAT_RESPONSE_COLUMNS = [
          *%i[id time created_at lineno cursorpos is_write project language entity branch category dependencies editor machine operating_system type project_root_count user_agent line_additions line_deletions ip_address lines source_type],
          :ja4_id
        ].freeze
        HEARTBEAT_FIELD_COLUMNS = {
          "projects" => "project",
          "languages" => "language",
          "entities" => "entity",
          "branches" => "branch",
          "categories" => "category",
          "editors" => "editor",
          "machines" => "machine",
          "user_agents" => "user_agent",
          "ips" => "ip_address"
        }.freeze

        def ip_machine_pairs
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          limit = parse_limit
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
              r1.user_id  AS user_a_id,
              r2.user_id  AS user_b_id,
              r1.machine,
              r1.ip_address,
              r1.first_seen AS user_a_first_seen,
              r1.last_seen  AS user_a_last_seen,
              r2.first_seen AS user_b_first_seen,
              r2.last_seen  AS user_b_last_seen
            FROM (
              SELECT user_id, machine, ip_address,
                     MIN(time) AS first_seen, MAX(time) AS last_seen
              FROM heartbeats
              WHERE user_id IS NOT NULL
                AND machine IS NOT NULL
                AND ip_address IS NOT NULL
                AND deleted_at IS NULL
                AND time > ?
              GROUP BY user_id, machine, ip_address
            ) r1
            JOIN (
              SELECT user_id, machine, ip_address,
                     MIN(time) AS first_seen, MAX(time) AS last_seen
              FROM heartbeats
              WHERE user_id IS NOT NULL
                AND machine IS NOT NULL
                AND ip_address IS NOT NULL
                AND deleted_at IS NULL
                AND time > ?
              GROUP BY user_id, machine, ip_address
            ) r2 ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE r1.user_id < r2.user_id
            LIMIT ?
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, cutoff, limit ])
          )

          render json: { pairs: result.to_a }
        end

        def shared_machines
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          limit = parse_limit
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
              sms.machine,
              sms.machine_frequency,
              ARRAY_AGG(DISTINCT u.id) AS user_ids
            FROM (
              SELECT machine, COUNT(user_id) AS machine_frequency
              FROM (
                SELECT DISTINCT machine, user_id
                FROM heartbeats
                WHERE machine IS NOT NULL
                  AND deleted_at IS NULL
                  AND time > ?
              ) AS user_machines
              GROUP BY machine
              HAVING COUNT(user_id) > 1
            ) AS sms
            JOIN heartbeats hb ON hb.machine = sms.machine AND hb.deleted_at IS NULL AND hb.time > ?
            JOIN users u ON u.id = hb.user_id
            GROUP BY sms.machine, sms.machine_frequency
            ORDER BY sms.machine_frequency DESC, sms.machine ASC
            LIMIT ?
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, cutoff, limit ])
          )

          render json: { machines: result.to_a }
        end

        def get_users_by_ip
          return render_error("bro dont got the ip") if params[:ip].blank?

          result = Heartbeat.where(ip_address: params[:ip]).select(:ip_address, :user_id, :machine, :user_agent).distinct
          render json: {
            users: result.map { |u|
              {
                user_id: u.user_id,
                ip_address: u.ip_address,
                machine: u.machine,
                user_agent: u.user_agent
              }
            }
          }
        end

        def get_users_by_machine
          return render_error("bro dont got the machine") if params[:machine].blank?

          result = Heartbeat.where(machine: params[:machine]).select(:user_id, :machine).distinct
          render json: { users: result.map { |u| { user_id: u.user_id, machine: u.machine } } }
        end

        def user_heartbeats
          user = find_user_by_id
          return unless user

          limit = (params[:limit] || 1000).to_i.clamp(1, 5_000)
          offset = (params[:offset] || 0).to_i.clamp(0, Float::INFINITY)

          query = user.heartbeats
          query = apply_time_range(query) or return
          %i[project language entity editor machine].each do |f|
            query = query.where(f => params[f]) if params[f].present?
          end

          total_count = query.count
          source_types = Heartbeat.source_types.invert
          rows = query.order(time: :asc, id: :asc).limit(limit).offset(offset).pluck(*HEARTBEAT_RESPONSE_COLUMNS)
          ja4s_by_id = Ja4.where(id: rows.filter_map(&:last).uniq).index_by(&:id)
          heartbeats = rows.map do |id, time, created_at, lineno, cursorpos, is_write, project, language, entity, branch, category, dependencies, editor, machine, operating_system, type, project_root_count, user_agent, line_additions, line_deletions, ip_address, lines, source_type, ja4_id|
            {
              id: id,
              time: time,
              created_at: created_at,
              project: project,
              branch: branch,
              category: category,
              dependencies: dependencies,
              editor: editor,
              entity: entity,
              language: language,
              machine: machine,
              operating_system: operating_system,
              type: type,
              user_agent: user_agent,
              line_additions: line_additions,
              line_deletions: line_deletions,
              lineno: lineno,
              lines: lines,
              cursorpos: cursorpos,
              project_root_count: project_root_count,
              is_write: is_write,
              source_type: source_types[source_type] || source_type,
              ip_address: ip_address,
              ja4: ja4s_by_id[ja4_id]&.then { |ja4| { fingerprint: ja4.fingerprint, name: ja4.name } }
            }
          end

          render json: {
            user_id: user.id,
            heartbeats: heartbeats,
            total_count: total_count,
            has_more: (offset + limit) < total_count
          }
        end

        def user_heartbeat_values
          user = find_user_by_id
          return unless user

          field = params[:field]
          column_name = HEARTBEAT_FIELD_COLUMNS[field]
          return render_error("invalid field") unless column_name

          limit = (params[:limit] || 5000).to_i.clamp(1, 5000)

          query = user.heartbeats
          query = apply_time_range(query) or return

          quoted_column = Heartbeat.connection.quote_column_name(column_name)
          values = query.where.not(column_name => nil).distinct
                        .order(Arel.sql("#{quoted_column} ASC"))
                        .limit(limit).pluck(column_name).reject(&:empty?)

          render json: { user_id: user.id, field: field, values: values, count: values.count }
        end

        private

        def parse_limit
          return DEFAULT_LIMIT unless params[:limit].present?

          parsed = params[:limit].to_i
          parsed.positive? ? parsed.clamp(1, MAX_LIMIT) : DEFAULT_LIMIT
        end
      end
    end
  end
end

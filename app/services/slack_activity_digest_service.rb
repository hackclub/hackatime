class SlackActivityDigestService
  Result = Struct.new(:blocks, :fallback_text, :period_start, :period_end, :total_seconds, :active_user_ids, keyword_init: true)

  def initialize(subscription:, as_of: Time.current)
    @subscription = subscription
    @reference_time = as_of
    @helpers = ApplicationController.helpers
  end

  def build
    users = users_in_channel
    user_records = users.to_a
    user_ids = user_records.map(&:id)
    period = digest_period

    heartbeat_scope = Heartbeat.where(user_id: user_ids)
                               .where("time >= ? AND time < ?", period[:start_epoch], period[:end_epoch])

    total_seconds = Heartbeat.duration_seconds(heartbeat_scope)

    per_user = Heartbeat.duration_seconds(heartbeat_scope.group(:user_id))
    per_project = Heartbeat.duration_seconds(heartbeat_scope.where.not(project: [ nil, "" ]).group(:project))

    active_user_ids = per_user.keys

    Result.new(
      blocks: build_blocks(user_records.index_by(&:id), period, total_seconds, per_user, per_project),
      fallback_text: fallback_text(period),
      period_start: period[:start_time],
      period_end: period[:end_time],
      total_seconds: total_seconds,
      active_user_ids: active_user_ids
    )
  end

  private

  def users_in_channel
    User.where(slack_neighborhood_channel: @subscription.slack_channel_id)
  end

  def digest_period
    tz = @subscription.active_time_zone
    reference_local = @reference_time.in_time_zone(tz)
    period_end = reference_local.beginning_of_day
    period_start = period_end - 1.day

    {
      start_time: period_start,
      end_time: period_end,
      start_epoch: period_start.to_i,
      end_epoch: period_end.to_i,
      timezone: tz
    }
  end

  def build_blocks(users_map, period, total_seconds, per_user, per_project)
    channel_mention = @subscription.channel_mention
    day_label = period[:start_time].strftime("%B %d")

    blocks = []

    header_text = "*Daily coding highlights for #{channel_mention} — #{day_label}*"
    blocks << { type: "section", text: { type: "mrkdwn", text: header_text } }

    if total_seconds.positive?
      active_count = per_user.length
      summary_text = "*Team total:* #{@helpers.short_time_detailed(total_seconds)} across #{active_count} #{'hacker'.pluralize(active_count)}"
      blocks << { type: "section", text: { type: "mrkdwn", text: summary_text } }
      blocks << { type: "divider" }

      add_top_users_block(blocks, users_map, per_user)
      add_top_projects_block(blocks, per_project)
    else
      blocks << { type: "section", text: { type: "mrkdwn", text: no_activity_text(period, channel_mention) } }
    end

    blocks
  end

  def add_top_users_block(blocks, users_map, per_user)
    return if per_user.blank?

    lines = per_user.sort_by { |_, seconds| -seconds }.first(5).each_with_index.map do |(user_id, seconds), index|
      user = users_map[user_id]
      handle = user&.slack_uid.present? ? "<@#{user.slack_uid}>" : user&.display_name || "User ##{user_id}"
      "#{index + 1}. #{handle} – #{@helpers.short_time_simple(seconds)}"
    end

    return if lines.empty?

    blocks << {
      type: "section",
      text: { type: "mrkdwn", text: "*Top hackers yesterday*\n" + lines.join("\n") }
    }
  end

  def add_top_projects_block(blocks, per_project)
    return if per_project.blank?

    lines = per_project.sort_by { |_, seconds| -seconds }.first(5).map do |project, seconds|
      project_name = project.presence || "Untitled"
      "• *#{project_name}* – #{@helpers.short_time_simple(seconds)}"
    end

    return if lines.empty?

    blocks << {
      type: "section",
      text: { type: "mrkdwn", text: "*Focus projects*\n" + lines.join("\n") }
    }
  end

  def no_activity_text(period, channel_mention)
    day_label = period[:start_time].strftime("%B %d")
    ":zzz: No coding activity recorded for #{channel_mention} on #{day_label}. Let’s ship something today!"
  end

  def fallback_text(period)
    day_label = period[:start_time].strftime("%B %d")
    "Daily coding highlights for #{day_label}"
  end
end

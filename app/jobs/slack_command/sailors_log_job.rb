class SlackCommand::SailorsLogJob < ApplicationJob
  queue_as :latency_10s

  def perform(params)
    case params[:text].downcase.strip
    when "on", "off"
      SlackCommand::SailorsLogOnOffJob.perform_now(
        params[:user_id],
        params[:channel_id],
        params[:user_name],
        params[:response_url],
        params[:text].downcase.strip == "on",
      )
    when "leaderboard"
      # Process in background
      SlackCommand::SailorsLogLeaderboardJob.perform_now(
        params[:user_id],
        params[:channel_id],
        params[:response_url],
      )
    else
      SlackCommand::SailorsLogHelpJob.perform_now(
        params[:response_url],
      )
    end
  end
end

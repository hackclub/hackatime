class SlackCommand::SailorsLogHelpJob < ApplicationJob
  queue_as :latency_10s

  def perform(response_url)
    HTTP.post(response_url, json: {
      response_type: "ephemeral",
      text: "Available commands: `/sailorslog on`, `/sailorslog off`, `/sailorslog leaderboard`"
    })
  end
end

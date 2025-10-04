class CreateHeartbeatActivityJob < ApplicationJob
  queue_as :default

  def perform(user_id, project_name)
    @user_id = user_id

    # Look for future coding activity only (not past events that are already showing)
    recent_activity = PublicActivity::Activity.with_future
      .where(owner_id: user_id, trackable_type: "Heartbeat", key: "coding_session")
      .where("created_at > ?", Time.current)
      .first

    if recent_activity
      # Keep pushing 5 minutes into future and update project/timing
      last_updated = Time.current.to_i
      started_at = recent_activity.parameters["started_at"]
      duration_seconds = last_updated - started_at

      recent_activity.update!(
        created_at: Time.current + 5.minutes,
        parameters: recent_activity.parameters.merge(
          project: project_name,
          last_updated: last_updated,
          duration_seconds: duration_seconds
        )
      )
    else
      return unless user

      # Create immediate "started working" activity - person just resumed coding
      PublicActivity::Activity.create!(
        trackable: user,
        owner: user,
        key: "started_working",
        parameters: { project: project_name }
      )

      # Create new session 5 minutes in future
      started_at = Time.current.to_i
      activity = PublicActivity::Activity.create!(
        trackable: user,
        owner: user,
        key: "coding_session",
        parameters: {
          project: project_name,
          started_at: started_at,
          last_updated: started_at,
          duration_seconds: 0
        },
        created_at: Time.current + 5.minutes
      )

      # Check if this is the user's first heartbeat ever
      if user.heartbeats.count == 1
        PublicActivity::Activity.create!(
          trackable: user,
          owner: user,
          key: "first_heartbeat",
          parameters: { project: project_name }
        )
      end
    end
  end

  private

  def user
    @user ||= User.find_by(id: @user_id)
  end
end

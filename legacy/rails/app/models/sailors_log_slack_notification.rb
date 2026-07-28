class SailorsLogSlackNotification < ApplicationRecord
  def notify_user!
    return if sent?

    SailorsLogNotifyJob.perform_now(self.id)
  end

  def notify_user_later!
    SailorsLogNotifyJob.perform_later(self.id)
  end
end

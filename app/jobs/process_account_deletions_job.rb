class ProcessAccountDeletionsJob < ApplicationJob
  queue_as :default

  def perform
    DeletionRequest.ready_for_deletion.find_each do |deletion_request|
      Rails.logger.info "kerblamming ##{deletion_request.user_id}"

      begin
        AnonymizeUserService.call(deletion_request.user)
        complete_request(deletion_request)

        Rails.logger.info "kerblamed account ##{deletion_request.user_id}"
      rescue StandardError => e
        report_error(e, message: "failed to kerblam ##{deletion_request.user_id}", extra: { user_id: deletion_request.user_id })
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  private

  def complete_request(deletion_request)
    unless HeartbeatRepository.clickhouse?
      deletion_request.complete!
      return
    end

    deletion = HeartbeatDeletion.find_by!(user_id: deletion_request.user_id)
    deletion_request.complete! if deletion.completed?
  end
end

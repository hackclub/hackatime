class ProcessAccountDeletionsJob < ApplicationJob
  queue_as :default

  def perform
    DeletionRequest.ready_for_deletion.find_each do |deletion_request|
      Rails.logger.info "kerblamming ##{deletion_request.user_id}"

      begin
        completed = deletion_request.with_lock do
          deletion_request.reload
          next false unless deletion_request.approved? && deletion_request.scheduled_deletion_at <= Time.current

          AnonymizeUserService.call(deletion_request.user)
          deletion_request.complete!
          true
        end
        next unless completed

        Rails.logger.info "kerblamed account ##{deletion_request.user_id}"
      rescue StandardError => e
        report_error(e, message: "failed to kerblam ##{deletion_request.user_id}", extra: { user_id: deletion_request.user_id })
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end

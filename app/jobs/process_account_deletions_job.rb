class ProcessAccountDeletionsJob < ApplicationJob
  queue_as :default

  def perform
    DeletionRequest.ready_for_deletion.find_each do |deletion_request|
      Rails.logger.info "kerblamming ##{deletion_request.user_id}"

      begin
        AnonymizeUserService.call(deletion_request.user)
        deletion_request.complete!

        Rails.logger.info "kerblamed account ##{deletion_request.user_id}"
      rescue StandardError => e
        Sentry.capture_exception(e, extra: { user_id: deletion_request.user_id })
        Rails.logger.error "failed to kerblam ##{deletion_request.user_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end

module My
  class MailroomController < ApplicationController
    before_action :ensure_current_user

    def index
      @user = current_user
      @physical_mails = @user.physical_mails.order(created_at: :desc)
      @has_mailing_address = @user.mailing_address.present?
    end

    private

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
    end
  end
end

module My
  class MailingAddressesController < ApplicationController
    before_action :ensure_current_user

    def show
      @user = current_user

      # Generate OTC if it doesn't exist
      if params[:from_fillout]
        sleep 1 # unfortunate hack to make sure the job runs after airtable gets the data
        FetchMailingAddressJob.perform_now(@user.id)
      else
        @user.update_column(:mailing_address_otc, SecureRandom.hex(8))
      end
    end

    def edit
      current_user.update_column(:mailing_address_otc, SecureRandom.hex(8))
      redirect_to "https://forms.hackclub.com/t/mo6hitqC6Vus?otc=#{current_user.mailing_address_otc}", allow_other_host: true
    end

    private

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
    end
  end
end

module Api
  module Admin
    module V1
      class ApplicationController < Api::Admin::ApplicationController
        private

        def find_user_by_id
          user_id = params[:id] || params[:user_id]
          return render_error("who?") if user_id.blank?
          User.find(user_id)
        rescue ActiveRecord::RecordNotFound
          render_not_found_json("user not found")
        end
      end
    end
  end
end

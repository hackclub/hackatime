# 🔧🐒

Rails.configuration.to_prepare do
  PaperTrail::Version.class_eval do
    def user
      begin
        User.find(whodunnit) if whodunnit
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end

  Doorkeeper::ApplicationsController.layout "application" # show oauth2 admin in normal hackatime ui

  PublicActivity::Activity.class_eval do
    default_scope { where("created_at <=", Time.current) }
    scope :with_future, -> { unscope(where: :created_at) }
  end
end

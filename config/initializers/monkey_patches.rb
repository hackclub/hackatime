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
end
class String
  # Hopefully this is the right place! It a really good monkey patch!!
  def categorize_language
    WakatimeService.categorize_language(self)
  end
end

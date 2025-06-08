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

  # Monkeypatch Airtable rate limit to be more conservative
  Norairrecord::Client.send(:remove_const, :AIRTABLE_RPS_LIMIT) if Norairrecord::Client.const_defined?(:AIRTABLE_RPS_LIMIT)
  Norairrecord::Client.const_set(:AIRTABLE_RPS_LIMIT, 2) # Set to 2 requests per second

  Doorkeeper::ApplicationsController.layout "application" # show oauth2 admin in normal hackatime ui
end

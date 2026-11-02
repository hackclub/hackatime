Rails.application.config.to_prepare do
  ActionDispatch::Session::ActiveRecordStore.session_class = WebSession
end

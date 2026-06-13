Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.ignore_actions = [ "Api::Hackatime::V1::HackatimeController#push_heartbeats" ]
  config.lograge.ignore_custom = lambda do |event|
    event.payload[:path] == "/up"
  end
end

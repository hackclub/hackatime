# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :_json, :hackatime, :heartbeat, :heartbeats,
  :branch, :category, :cursorpos, :dependencies, :editor, :entity, :is_write, :language,
  :line_additions, :line_deletions, :lineno, :lines, :machine, :operating_system,
  :plugin, :project, :project_root_count, :time, :type, :user_agent
]

# Enable autotuner. Alternatively, call Autotuner.sample_ratio= with a value
# between 0 and 1.0 to sample on a portion of instances.
Autotuner.enabled = true

Autotuner.reporter = proc do |report|
  Sentry.capture_message(
    "Autotuner Suggestion",
    level: :info,
    extra: { report: report.to_s }
  )
end

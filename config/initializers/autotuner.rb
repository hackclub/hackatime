if Rails.env.production?
  Autotuner.enabled = true

  Autotuner.reporter = proc do |report|
    Sentry.capture_message(
      "Autotuner Suggestion",
      level: :info,
      extra: { report: report.to_s }
    )
  end
end

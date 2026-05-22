# Autotuner reports GC tuning suggestions to Sentry. Only useful in production
# where we'd act on the suggestions — in dev/test the per-request GC sampling
# is dead weight and the suggestions go nowhere.
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

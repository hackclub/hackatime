# Scoring weights, thresholds and output-ceiling rates. The code is AGPL, so
# these defaults are deliberately only reasonable starting points: production
# loads its real values from a private file named by EVIDENCE_CONFIG_PATH
# (YAML or JSON, deep-merged over the defaults). The optional trained model
# lives at EVIDENCE_MODEL_PATH; without it scoring is rules-only.
module Evidence
  module Config
    DEFAULTS = {
      grace_seconds: 120,
      follow_up_seconds: 600,
      no_follow_up_cap_seconds: 600,
      jiggler_threshold: 0.8,
      injected_ratio_threshold: 0.3,
      human_rhythm_floor: 0.35,
      duplicate_frame_run: 3,
      timelapse_window_seconds: 30,
      clock_skew_seconds: 300,
      offline_max_seconds: 86_400,
      offline_penalty: 0.7,
      high_confidence: 0.8,
      medium_confidence: 0.6,
      weights: {
        streams_agree: 0.2,
        follow_up: 0.3,
        build_changed: 0.15,
        human_input: 0.15,
        frames_present: 0.15,
        hardware_key: 0.05,
        attested: 0.1
      },
      ceiling: {
        base_seconds: 1_800,
        seconds_per_human_line: 150,
        seconds_per_ai_line: 20,
        seconds_per_new_file: 300,
        research_allowance: 0.25
      },
      plausibility: {
        winnow_k: 25,
        winnow_window: 4,
        min_overlap: 0.15
      }
    }.freeze

    module_function

    def current
      return @current if @current && !Rails.env.local?

      @current = DEFAULTS.deep_merge(private_overrides)
    end

    def reset! = @current = nil

    def private_overrides
      path = ENV["EVIDENCE_CONFIG_PATH"].presence
      return {} unless path && File.file?(path)

      YAML.safe_load_file(path, permitted_classes: [ Symbol ]).to_h.deep_symbolize_keys
    end
  end
end

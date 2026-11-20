# Optional calibrated tree ensemble, CPU only. Production trains it offline
# (script/evidence/train_model.py) on distilled labels and keeps the export
# private at EVIDENCE_MODEL_PATH. The file is LightGBM's `dump_model()` JSON
# plus `feature_names` and an isotonic `calibration` table. Without it the
# scorer uses the rules-only weights.
module Evidence
  class Model
    FEATURES = %w[
      minutes active_ratio keys_per_min clicks_per_min moves_per_min injected_ratio rhythm jiggler
      ai_prompts ai_waiting_ratio edits commits builds tree_changes frames frames_due frames_on_time
      research_ratio unrelated_ratio follow_up offline_ratio signed_ratio duplicate_frames hardware_tier
    ].freeze

    def self.load
      path = ENV["EVIDENCE_MODEL_PATH"].presence
      return unless path && File.file?(path)

      @cache = nil if @cache && @cache[0] != [ path, File.mtime(path) ]
      (@cache ||= [ [ path, File.mtime(path) ], new(JSON.parse(File.read(path))) ])[1]
    end

    attr_reader :name

    def initialize(dump)
      @feature_index = dump.fetch("feature_names").each_with_index.to_h
      @trees = dump.fetch("tree_info").map { |tree| tree.fetch("tree_structure") }
      @sigmoid = dump.fetch("objective", "binary").to_s.start_with?("binary")
      calibration = dump["calibration"] || {}
      @cal_x = Array(calibration["x"])
      @cal_y = Array(calibration["y"])
      @name = dump["name"] || "lightgbm"
    end

    def predict(features)
      row = Array.new(@feature_index.size, 0.0)
      features.each { |key, value| (index = @feature_index[key.to_s]) && row[index] = value.to_f }
      raw = @trees.sum { |node| leaf(node, row) }
      calibrate(@sigmoid ? 1.0 / (1.0 + Math.exp(-raw)) : raw).clamp(0.0, 1.0)
    end

    private

    def leaf(node, row)
      until node.key?("leaf_value")
        value = row[node["split_feature"]]
        left = value.nil? || value.nan? ? node["default_left"] : value <= node["threshold"]
        node = left ? node["left_child"] : node["right_child"]
      end
      node["leaf_value"]
    end

    # Piecewise-linear isotonic map, as exported from scikit-learn's
    # IsotonicRegression (X_thresholds_, y_thresholds_).
    def calibrate(probability)
      return probability if @cal_x.empty?
      return @cal_y.first if probability <= @cal_x.first
      return @cal_y.last if probability >= @cal_x.last

      upper = @cal_x.bsearch_index { |x| x >= probability }
      x0, x1 = @cal_x[upper - 1], @cal_x[upper]
      y0, y1 = @cal_y[upper - 1], @cal_y[upper]
      x1 == x0 ? y1 : y0 + (y1 - y0) * (probability - x0) / (x1 - x0)
    end
  end
end

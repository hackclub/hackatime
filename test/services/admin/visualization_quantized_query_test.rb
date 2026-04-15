require "test_helper"

module Admin
  class VisualizationQuantizedQueryTest < ActiveSupport::TestCase
    test "returns quantized days for a month" do
      user = User.create!(timezone: "UTC")

      Heartbeat.create!(
        user: user,
        time: Time.utc(2026, 1, 10, 12, 0, 0).to_i,
        lineno: 10,
        cursorpos: 40,
        source_type: :test_entry
      )

      result = VisualizationQuantizedQuery.new(user: user, year: 2026, month: 1).call

      assert result.success?
      assert_equal 31, result.days.length

      day = result.days.find { |d| Time.at(d[:date_timestamp_s]).utc.to_date == Date.new(2026, 1, 10) }
      assert_not_nil day
      assert_equal 1, day[:points].length
      assert_equal 10, day[:points].first[:lineno]
      assert_equal 40, day[:points].first[:cursorpos]
    end

    test "returns invalid parameters for out-of-range month" do
      user = User.create!(timezone: "UTC")

      result = VisualizationQuantizedQuery.new(user: user, year: 2026, month: 13).call

      assert_not result.success?
      assert_equal :invalid_parameters, result.error
    end

    test "accepts very large years without crashing" do
      user = User.create!(timezone: "UTC")

      result = VisualizationQuantizedQuery.new(user: user, year: 100_000, month: 1).call

      assert result.success?
      assert_equal 31, result.days.length
    end
  end
end

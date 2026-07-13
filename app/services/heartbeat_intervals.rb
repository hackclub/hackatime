module HeartbeatIntervals
  DIMENSIONS = %i[project language editor operating_system machine category entity branch].freeze
  VALID_TIME_RANGE = 0..253402300799
  NULL_DIMENSION_VALUE = "__HACKATIME_NULL_DIMENSION_7F3D8C2A__".freeze
end

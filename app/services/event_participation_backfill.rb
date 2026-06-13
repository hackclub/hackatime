class EventParticipationBackfill
  def self.call(scope: User.where(event_participation_backfilled: false)) = new(scope: scope).call

  def initialize(scope:)
    @scope = scope
  end

  def call
    count = 0
    @scope.find_each do |user|
      user.update_columns(
        event_participation: event_participation_mask(user),
        event_participation_backfilled: true,
        updated_at: Time.current
      )
      count += 1
    end
    count
  end

  private

  def event_participation_mask(user)
    TimeRangeFilterable::EVENT_KEYS.each_with_index.reduce(0) do |mask, (key, index)|
      range = TimeRangeFilterable::EVENT_RANGES.fetch(key).fetch(:calculate).call
      participated = user.heartbeats.where(time: range.begin.to_f..range.end.to_f).exists?
      participated ? mask | (1 << index) : mask
    end
  end
end

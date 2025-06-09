class Neighborhood::TriggerTimeUpdateJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit 1

  def perform
    posts = Neighborhood::Post
      .where("(airtable_fields->>'action-triggerHackatimeTimeUpdate') IS NULL")
      .order(Arel.sql("(airtable_fields->>'lastTimeUpdateAt') IS NULL ASC, (airtable_fields->>'lastTimeUpdateAt')::timestamp ASC"))
      .limit(10)
      .pluck(:airtable_id)

    records = posts.map { |id| table.new({}, id: id).tap { |rec| rec["action-triggerHackatimeTimeUpdate"] = true } }
    updates = table.batch_update(records)

    return unless updates.any?

    upsert_fields = updates.map { |update| { airtable_id: update.id, airtable_fields: update.fields } }
    Neighborhood::Post.upsert_all(upsert_fields, unique_by: :airtable_id)
  end

  private

  def table
    @table ||= Neighborhood::Post.table
  end
end

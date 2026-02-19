class CreateGoals < ActiveRecord::Migration[8.1]
  PERIODS = %w[day week month].freeze

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationGoal < ActiveRecord::Base
    self.table_name = "goals"
  end

  def up
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period, null: false
      t.integer :target_seconds, null: false
      t.string :languages, array: true, default: [], null: false
      t.string :projects, array: true, default: [], null: false
      t.timestamps
    end unless table_exists?(:goals)

    add_index :goals,
      [ :user_id, :period, :target_seconds, :languages, :projects ],
      unique: true,
      name: "index_goals_on_user_and_scope",
      if_not_exists: true

    migrate_from_users_programming_goals

    remove_column :users, :programming_goals, :jsonb if column_exists?(:users, :programming_goals)
  end

  def down
    add_column :users, :programming_goals, :jsonb, null: false, default: [] unless column_exists?(:users, :programming_goals)

    return unless table_exists?(:goals)

    execute <<~SQL
      UPDATE users
      SET programming_goals = goals_payload.goals
      FROM (
        SELECT
          user_id,
          COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', id::text,
                'period', period,
                'target_seconds', target_seconds,
                'languages', languages,
                'projects', projects
              )
              ORDER BY id
            ),
            '[]'::jsonb
          ) AS goals
        FROM goals
        GROUP BY user_id
      ) AS goals_payload
      WHERE users.id = goals_payload.user_id
    SQL

    drop_table :goals
  end

  private

  def migrate_from_users_programming_goals
    return unless column_exists?(:users, :programming_goals)
    return unless table_exists?(:goals)

    say_with_time "Migrating users.programming_goals into goals table" do
      MigrationUser.reset_column_information
      MigrationGoal.reset_column_information

      MigrationUser.find_each do |user|
        seen_signatures = {}

        Array(user.read_attribute(:programming_goals)).each do |goal|
          next unless goal.is_a?(Hash)

          period = goal["period"].to_s
          target_seconds = goal["target_seconds"].to_i
          languages = Array(goal["languages"]).map(&:to_s).reject(&:blank?).uniq
          projects = Array(goal["projects"]).map(&:to_s).reject(&:blank?).uniq

          next unless PERIODS.include?(period)
          next unless target_seconds.positive?

          signature = [ period, target_seconds, languages, projects ]
          next if seen_signatures[signature]

          seen_signatures[signature] = true

          MigrationGoal.find_or_create_by!(
            user_id: user.id,
            period: period,
            target_seconds: target_seconds,
            languages: languages,
            projects: projects
          )
        end
      end
    end
  end
end

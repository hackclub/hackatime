module HeartbeatDimensionResolver
  extend ActiveSupport::Concern

  included do
    belongs_to :heartbeat_language, class_name: "Heartbeats::Language", foreign_key: :language_id, optional: true
    belongs_to :heartbeat_category, class_name: "Heartbeats::Category", foreign_key: :category_id, optional: true
    belongs_to :heartbeat_editor, class_name: "Heartbeats::Editor", foreign_key: :editor_id, optional: true
    belongs_to :heartbeat_operating_system, class_name: "Heartbeats::OperatingSystem", foreign_key: :operating_system_id, optional: true
    belongs_to :heartbeat_user_agent, class_name: "Heartbeats::UserAgent", foreign_key: :user_agent_id, optional: true
    belongs_to :heartbeat_project, class_name: "Heartbeats::Project", foreign_key: :project_id, optional: true
    belongs_to :heartbeat_branch, class_name: "Heartbeats::Branch", foreign_key: :branch_id, optional: true
    belongs_to :heartbeat_machine, class_name: "Heartbeats::Machine", foreign_key: :machine_id, optional: true

    before_save :resolve_dimension_ids, if: :should_resolve_dimensions?
  end

  private

  def should_resolve_dimensions?
    Flipper.enabled?(:heartbeat_dimension_dual_write)
  end

  def resolve_dimension_ids
    self.language_id ||= Heartbeats::Language.resolve(language)&.id if language.present?
    self.category_id ||= Heartbeats::Category.resolve(category)&.id if category.present?
    self.editor_id ||= Heartbeats::Editor.resolve(editor)&.id if editor.present?
    self.operating_system_id ||= Heartbeats::OperatingSystem.resolve(operating_system)&.id if operating_system.present?
    self.user_agent_id ||= Heartbeats::UserAgent.resolve(user_agent)&.id if user_agent.present?
    self.project_id ||= Heartbeats::Project.resolve(user_id, project)&.id if project.present? && user_id.present?
    self.branch_id ||= Heartbeats::Branch.resolve(user_id, branch)&.id if branch.present? && user_id.present?
    self.machine_id ||= Heartbeats::Machine.resolve(user_id, machine)&.id if machine.present? && user_id.present?
  end

  class_methods do
    def resolve_dimensions_for_attributes(attrs)
      user_id = attrs[:user_id]

      attrs[:language_id] ||= Heartbeats::Language.resolve(attrs[:language])&.id if attrs[:language].present?
      attrs[:category_id] ||= Heartbeats::Category.resolve(attrs[:category])&.id if attrs[:category].present?
      attrs[:editor_id] ||= Heartbeats::Editor.resolve(attrs[:editor])&.id if attrs[:editor].present?
      attrs[:operating_system_id] ||= Heartbeats::OperatingSystem.resolve(attrs[:operating_system])&.id if attrs[:operating_system].present?
      attrs[:user_agent_id] ||= Heartbeats::UserAgent.resolve(attrs[:user_agent])&.id if attrs[:user_agent].present?
      attrs[:project_id] ||= Heartbeats::Project.resolve(user_id, attrs[:project])&.id if attrs[:project].present? && user_id.present?
      attrs[:branch_id] ||= Heartbeats::Branch.resolve(user_id, attrs[:branch])&.id if attrs[:branch].present? && user_id.present?
      attrs[:machine_id] ||= Heartbeats::Machine.resolve(user_id, attrs[:machine])&.id if attrs[:machine].present? && user_id.present?

      attrs
    end

    def batch_resolve_dimensions(records_attrs)
      return records_attrs unless Flipper.enabled?(:heartbeat_dimension_dual_write)

      global_languages = records_attrs.map { |r| r[:language] }.compact.uniq
      global_categories = records_attrs.map { |r| r[:category] }.compact.uniq
      global_editors = records_attrs.map { |r| r[:editor] }.compact.uniq
      global_operating_systems = records_attrs.map { |r| r[:operating_system] }.compact.uniq
      global_user_agents = records_attrs.map { |r| r[:user_agent] }.compact.uniq

      language_map = batch_resolve_global(Heartbeats::Language, :name, global_languages)
      category_map = batch_resolve_global(Heartbeats::Category, :name, global_categories)
      editor_map = batch_resolve_global(Heartbeats::Editor, :name, global_editors)
      os_map = batch_resolve_global(Heartbeats::OperatingSystem, :name, global_operating_systems)
      ua_map = batch_resolve_global(Heartbeats::UserAgent, :value, global_user_agents)

      user_projects = records_attrs.map { |r| [ r[:user_id], r[:project] ] }.select { |u, p| u && p }.uniq
      user_branches = records_attrs.map { |r| [ r[:user_id], r[:branch] ] }.select { |u, b| u && b }.uniq
      user_machines = records_attrs.map { |r| [ r[:user_id], r[:machine] ] }.select { |u, m| u && m }.uniq

      project_map = batch_resolve_user_scoped(Heartbeats::Project, user_projects)
      branch_map = batch_resolve_user_scoped(Heartbeats::Branch, user_branches)
      machine_map = batch_resolve_user_scoped(Heartbeats::Machine, user_machines)

      records_attrs.map do |attrs|
        attrs = attrs.dup
        attrs[:language_id] ||= language_map[attrs[:language]] if attrs[:language]
        attrs[:category_id] ||= category_map[attrs[:category]] if attrs[:category]
        attrs[:editor_id] ||= editor_map[attrs[:editor]] if attrs[:editor]
        attrs[:operating_system_id] ||= os_map[attrs[:operating_system]] if attrs[:operating_system]
        attrs[:user_agent_id] ||= ua_map[attrs[:user_agent]] if attrs[:user_agent]
        attrs[:project_id] ||= project_map[[ attrs[:user_id], attrs[:project] ]] if attrs[:project] && attrs[:user_id]
        attrs[:branch_id] ||= branch_map[[ attrs[:user_id], attrs[:branch] ]] if attrs[:branch] && attrs[:user_id]
        attrs[:machine_id] ||= machine_map[[ attrs[:user_id], attrs[:machine] ]] if attrs[:machine] && attrs[:user_id]
        attrs
      end
    end

    private

    def batch_resolve_global(model, column, values)
      return {} if values.empty?

      now = Time.current
      rows = values.map { |v| { column => v, created_at: now, updated_at: now } }
      model.upsert_all(rows, unique_by: column, returning: [ :id, column ])

      model.where(column => values).pluck(column, :id).to_h
    end

    def batch_resolve_user_scoped(model, user_value_pairs)
      return {} if user_value_pairs.empty?

      now = Time.current
      rows = user_value_pairs.map { |user_id, name| { user_id: user_id, name: name, created_at: now, updated_at: now } }
      model.upsert_all(rows, unique_by: [ :user_id, :name ], returning: [ :id, :user_id, :name ])

      model.where(
        user_value_pairs.map { |uid, name| "(user_id = #{uid} AND name = #{model.connection.quote(name)})" }.join(" OR ")
      ).pluck(:user_id, :name, :id).each_with_object({}) do |(uid, name, id), h|
        h[[ uid, name ]] = id
      end
    end
  end
end

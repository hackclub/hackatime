module HeartbeatDimensionResolver
  extend ActiveSupport::Concern

  DIMENSIONS = {
    language:         { model: "Heartbeats::Language",        value_attr: :language,         fk: :language_id,         lookup: :name,  scope: :global },
    category:         { model: "Heartbeats::Category",        value_attr: :category,         fk: :category_id,         lookup: :name,  scope: :global },
    editor:           { model: "Heartbeats::Editor",          value_attr: :editor,           fk: :editor_id,           lookup: :name,  scope: :global },
    operating_system: { model: "Heartbeats::OperatingSystem", value_attr: :operating_system, fk: :operating_system_id, lookup: :name,  scope: :global },
    user_agent:       { model: "Heartbeats::UserAgent",       value_attr: :user_agent,       fk: :user_agent_id,       lookup: :value, scope: :global },
    project:          { model: "Heartbeats::Project",         value_attr: :project,          fk: :project_id,          lookup: :name,  scope: :user },
    branch:           { model: "Heartbeats::Branch",          value_attr: :branch,           fk: :branch_id,           lookup: :name,  scope: :user },
    machine:          { model: "Heartbeats::Machine",         value_attr: :machine,          fk: :machine_id,          lookup: :name,  scope: :user }
  }.freeze

  included do
    DIMENSIONS.each do |key, spec|
      belongs_to :"heartbeat_#{key}",
        class_name: spec[:model],
        foreign_key: spec[:fk],
        optional: true
    end

    before_save :resolve_dimension_ids, if: :should_resolve_dimensions?
  end

  private

  def should_resolve_dimensions?
    Flipper.enabled?(:heartbeat_dimension_dual_write)
  end

  def resolve_dimension_ids
    DIMENSIONS.each_value do |spec|
      next if self[spec[:fk]].present?

      value = self[spec[:value_attr]]
      next if value.blank?

      model = spec[:model].constantize
      resolved_id = if spec[:scope] == :global
        model.resolve(value)&.id
      else
        model.resolve(user_id, value)&.id if user_id.present?
      end

      self[spec[:fk]] = resolved_id if resolved_id
    end
  end

  class_methods do
    def resolve_dimensions_for_attributes(attrs)
      user_id = attrs[:user_id]

      DIMENSIONS.each_value do |spec|
        next if attrs[spec[:fk]].present?

        value = attrs[spec[:value_attr]]
        next if value.blank?

        model = spec[:model].constantize
        attrs[spec[:fk]] = if spec[:scope] == :global
          model.resolve(value)&.id
        else
          model.resolve(user_id, value)&.id if user_id.present?
        end
      end

      attrs
    end

    def batch_resolve_dimensions(records_attrs)
      return records_attrs unless Flipper.enabled?(:heartbeat_dimension_dual_write)

      global_specs = DIMENSIONS.select { |_, s| s[:scope] == :global }
      user_specs = DIMENSIONS.select { |_, s| s[:scope] == :user }

      global_maps = global_specs.transform_values do |spec|
        values = records_attrs.filter_map { |r| r[spec[:value_attr]] }.uniq
        batch_resolve_global(spec[:model].constantize, spec[:lookup], values)
      end

      user_maps = user_specs.transform_values do |spec|
        pairs = records_attrs.filter_map { |r|
          uid, val = r[:user_id], r[spec[:value_attr]]
          [ uid, val ] if uid && val
        }.uniq
        batch_resolve_user_scoped(spec[:model].constantize, pairs)
      end

      records_attrs.map do |attrs|
        attrs = attrs.dup

        global_specs.each do |key, spec|
          next if attrs[spec[:fk]].present?
          attrs[spec[:fk]] = global_maps[key][attrs[spec[:value_attr]]] if attrs[spec[:value_attr]]
        end

        user_specs.each do |key, spec|
          next if attrs[spec[:fk]].present?
          attrs[spec[:fk]] = user_maps[key][[ attrs[:user_id], attrs[spec[:value_attr]] ]] if attrs[spec[:value_attr]] && attrs[:user_id]
        end

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

      model.where([ "(user_id, name) IN (?)", user_value_pairs ])
           .pluck(:user_id, :name, :id)
           .each_with_object({}) { |(uid, name, id), h| h[[ uid, name ]] = id }
    end
  end
end

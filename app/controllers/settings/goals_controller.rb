class Settings::GoalsController < Settings::BaseController
  def create
    @goal = @user.goals.build(goal_params)
    if @goal.save
      redirect_to my_settings_goals_path, notice: "Goal created."
    else
      flash.now[:error] = @goal.errors.full_messages.to_sentence
      render_goals(status: :unprocessable_entity, goal_form: goal_form_props(@goal, "create"))
    end
  end

  def update
    @goal = @user.goals.find(params[:goal_id])
    if @goal.update(goal_params)
      redirect_to my_settings_goals_path, notice: "Goal updated."
    else
      flash.now[:error] = @goal.errors.full_messages.to_sentence
      render_goals(status: :unprocessable_entity, goal_form: goal_form_props(@goal, "edit"))
    end
  end

  def destroy
    @user.goals.find(params[:goal_id]).destroy!
    redirect_to my_settings_goals_path, notice: "Goal deleted."
  end

  private

  def render_goals(status: :ok, goal_form: nil)
    extra_props = goal_form ? { goal_form: goal_form } : {}
    render_settings_page(status: status, extra_props: extra_props)
  end

  def page_props
    { programming_goals: programming_goals_props, options: { goals: goal_options } }
  end

  def programming_goals_props
    @user.goals.order(:created_at).map(&:as_programming_goal_payload)
  end

  def goal_options
    goal_languages = []
    goal_projects = @user.project_repo_mappings.distinct.pluck(:project_name)

    @user.heartbeats.distinct.pluck(:language, :project).each do |language, project|
      categorized = language&.categorize_language
      goal_languages << categorized if categorized.present?
      goal_projects << project if project.present?
    end

    {
      periods: Goal::PERIODS.map { |p| { label: p.humanize, value: p } },
      preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
      selectable_languages: goal_languages.uniq.sort.map { |l| { label: l, value: l } },
      selectable_projects: goal_projects.uniq.sort.map { |p| { label: p, value: p } }
    }
  end

  def goal_params = params.require(:goal).permit(:period, :target_seconds, languages: [], projects: [])

  def goal_form_props(goal, mode)
    { open: true, mode: mode, goal_id: goal.id&.to_s,
      period: goal.period, target_seconds: goal.target_seconds,
      languages: goal.languages, projects: goal.projects,
      errors: goal.errors.full_messages }
  end
end

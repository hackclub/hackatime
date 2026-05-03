class Settings::GoalsController < Settings::BaseController
  def show
    render_goals
  end

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
    @goal = @user.goals.find(params[:goal_id])
    @goal.destroy!
    redirect_to my_settings_goals_path, notice: "Goal deleted."
  end

  private

  def render_goals(status: :ok, goal_form: nil)
    extra_props = {}
    extra_props[:goal_form] = goal_form if goal_form

    render_settings_page(
      active_section: "goals",
      settings_update_path: my_settings_goals_path,
      status: status,
      extra_props: extra_props
    )
  end

  def section_props
    {
      settings_update_path: my_settings_goals_path,
      create_goal_path: my_settings_goals_create_path,
      programming_goals: programming_goals_props,
      options: { goals: goal_options }
    }
  end

  def goal_params
    params.require(:goal).permit(:period, :target_seconds, languages: [], projects: [])
  end

  def goal_form_props(goal, mode)
    {
      open: true,
      mode: mode,
      goal_id: goal.id&.to_s,
      period: goal.period,
      target_seconds: goal.target_seconds,
      languages: goal.languages,
      projects: goal.projects,
      errors: goal.errors.full_messages
    }
  end
end

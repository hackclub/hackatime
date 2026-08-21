class Settings::GoalsController < Settings::BaseController
  def show = render_goals

  def create
    @goal = @user.goals.build(goal_params)
    if @goal.save
      ensure_goal_email_subscription
      redirect_to my_settings_goals_path, notice: "Goal created."
    else
      flash.now[:error] = @goal.errors.full_messages.to_sentence
      render_goals(status: :unprocessable_entity, goal_form: goal_form_props(@goal, "create"))
    end
  end

  def update
    @goal = @user.goals.find(params[:goal_id])
    if @goal.update(goal_params)
      ensure_goal_email_subscription
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
    render_settings_page(active_section: "goals", status: status, extra_props: extra_props)
  end

  def section_props
    { programming_goals: programming_goals_props, options: { goals: goal_options } }
  end

  def goal_options
    goal_languages = []
    goal_projects = project_list.map { |p| p[:display_name] }

    @user.heartbeats.distinct.pluck(:language, :project).each do |language, project|
      categorized = language&.categorize_language
      goal_languages << categorized if categorized.present?
      goal_projects << project if project.present?
    end

    {
      periods: Goal::PERIODS.map { |p| { label: p.humanize, value: p } },
      preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
      selectable_languages: goal_languages.uniq.sort.map { |l| { label: l, value: l } },
      selectable_projects: goal_projects.uniq.sort.map { |p| { label: p, value: p } },
      slack_available: @user.slack_uid.present?,
      email_available: @user.email_addresses.exists?
    }
  end

  def goal_params
    params.require(:goal).permit(:period, :target_seconds, :notify_slack, :notify_email, languages: [], projects: [])
  end

  # Opt the user back into the goal_notifications list when they enable email
  # notifications on any goal, so an earlier unsubscribe via a mail footer does
  # not silently swallow newly enabled goals.
  def ensure_goal_email_subscription
    @user.subscribe("goal_notifications") if @goal.notify_email? && !@user.subscribed?("goal_notifications")
  end

  def goal_form_props(goal, mode)
    { open: true, mode: mode, goal_id: goal.id&.to_s,
      period: goal.period, target_seconds: goal.target_seconds,
      languages: goal.languages, projects: goal.projects,
      notify_slack: goal.notify_slack, notify_email: goal.notify_email,
      errors: goal.errors.full_messages }
  end
end

class Settings::BadgesController < Settings::BaseController
  private

  def page_props
    {
      badge_themes: GithubReadmeStats.themes,
      badges: badges_props,
      allow_public_stats_lookup: @user.allow_public_stats_lookup
    }
  end

  def badges_props
    work_time_stats_base_url = "#{request.base_url}/api/v1/badge/#{badge_user_id}/"
    work_time_stats_url = (project_list.first.present? ? "#{work_time_stats_base_url}#{project_list.first[:repo_path]}" : nil)

    {
      general_badge_url: GithubReadmeStats.new(@user.id, "darcula").generate_badge_url,
      project_badge_url: work_time_stats_url,
      project_badge_base_url: work_time_stats_base_url,
      projects: project_list,
      markscribe_template: '{{ wakatimeDoubleCategoryBar "Languages:" wakatimeData.Languages "Projects:" wakatimeData.Projects 5 }}',
      markscribe_reference_url: "https://github.com/taciturnaxolotl/markscribe#your-wakatime-languages-formated-as-a-bar",
      markscribe_preview_image_url: "https://cdn.fluff.pw/slackcdn/524e293aa09bc5f9115c0c29c18fb4bc.png",
      heatmap_badge_url: "https://heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      heatmap_config_url: "https://hackatime-heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      hackabox_repo_url: "https://github.com/quackclub/hacka-box",
      hackabox_preview_image_url: "https://user-cdn.hackclub-assets.com/019cef81-366a-7543-ad7c-21b738310f23/image.png"
    }
  end

  def project_list
    @project_list ||= @user.project_repo_mappings.includes(:repository).distinct.map do |mapping|
      { display_name: mapping.project_name,
        repo_path: mapping.repository&.full_path || mapping.project_name }
    end
  end

  def badge_user_id = @user.slack_uid.presence || @user.username.presence || @user.id.to_s
end

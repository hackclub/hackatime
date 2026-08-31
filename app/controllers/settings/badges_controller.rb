class Settings::BadgesController < Settings::BaseController
  private

  def section_props
    {
      badge_themes: GithubReadmeStats.themes,
      badges: badges_props,
      allow_public_stats_lookup: @user.allow_public_stats_lookup
    }
  end
end

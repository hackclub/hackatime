class GithubReadmeStats
  THEMES = Rails.root.join("config/themes.txt").readlines(chomp: true).reject(&:empty?).freeze

  def initialize(user_id = nil, theme = nil)
    @user_id = user_id || "{YOUR_USER_ID}"
    @theme = theme || THEMES.first
  end

  def generate_badge_url
    url = URI.parse("https://github-readme-stats.hackclub.dev/api/wakatime")
    url.query = URI.encode_www_form(
      username: @user_id, api_domain: "hackatime.hackclub.com",
      theme: @theme, custom_title: "Hackatime Stats", layout: "compact",
      cache_seconds: 0, langs_count: 8
    )
    url.to_s
  end

  def self.themes = THEMES
end

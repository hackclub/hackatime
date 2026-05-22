class GithubReadmeStats
  THEMES = %w[
    default transparent shadow_red shadow_green shadow_blue dark radical merko
    gruvbox gruvbox_light tokyonight onedark cobalt synthwave highcontrast
    dracula prussian monokai nightowl buefy blue-green algolia great-gatsby
    darcula bear solarized-dark solarized-light chartreuse-dark nord gotham
    material-palenight graywhite vision-friendly-dark ayu-mirage midnight-purple
    calm flag-india omni react slateorange kacho_ga outrun ocean_dark city_lights
    github_dark github_dark_dimmed discord_old_blurple aura_dark panda
    noctis_minimus cobalt2 swift aura apprentice moltack codeSTACKr rose_pine
    catppuccin_latte catppuccin_mocha date_night one_dark_pro rose holi neon
    blue_navy calm_pink ambient_gradient
  ].freeze

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

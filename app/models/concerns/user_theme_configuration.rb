module UserThemeConfiguration
  extend ActiveSupport::Concern

  DEFAULT_THEME = "gruvbox_dark".freeze
  THEME_OPTIONS = [
    {
      value: "standard",
      label: "Classic",
      description: "Current Hackatime look.",
      color_scheme: "dark",
      theme_color: "#c8394f",
      preview: {
        darker: "#1f1617",
        dark: "#2a1f21",
        darkless: "#4a2d31",
        primary: "#c8394f",
        content: "#f3ecee",
        info: "#5bc0de",
        success: "#33d6a6",
        warning: "#f1c40f"
      }
    },
    {
      value: "neon",
      label: "Neon",
      description: "Dark mode with neon green primary.",
      color_scheme: "dark",
      theme_color: "#d7ff6a",
      preview: {
        darker: "#050505",
        dark: "#101312",
        darkless: "#242a28",
        primary: "#d7ff6a",
        content: "#e8eee9",
        info: "#6fd7ff",
        success: "#7dfc6a",
        warning: "#ffd166"
      }
    },
    {
      value: "catppuccin_mocha",
      label: "Catppuccin Mocha",
      description: "Warm purple-tinted dark palette.",
      color_scheme: "dark",
      theme_color: "#cba6f7",
      preview: {
        darker: "#11111b",
        dark: "#181825",
        darkless: "#313244",
        primary: "#cba6f7",
        content: "#cdd6f4",
        info: "#89b4fa",
        success: "#a6e3a1",
        warning: "#f9e2af"
      }
    },
    {
      value: "catppuccin_iced_latte",
      label: "Catppuccin Iced Latte",
      description: "Cool light Catppuccin variant.",
      color_scheme: "light",
      theme_color: "#1e66f5",
      preview: {
        darker: "#ccd0da",
        dark: "#dce0e8",
        darkless: "#bac2de",
        primary: "#1e66f5",
        content: "#4c4f69",
        info: "#209fb5",
        success: "#40a02b",
        warning: "#df8e1d"
      }
    },
    {
      value: "gruvbox_dark",
      label: "Gruvbox Dark",
      description: "Retro warm dark tones.",
      color_scheme: "dark",
      theme_color: "#d8a657",
      preview: {
        darker: "#1d2021",
        dark: "#282828",
        darkless: "#3c3836",
        primary: "#d8a657",
        content: "#ebdbb2",
        info: "#83a598",
        success: "#b8bb26",
        warning: "#fabd2f"
      }
    },
    {
      value: "github_dark",
      label: "GitHub Dark",
      description: "GitHub's classic dark palette.",
      color_scheme: "dark",
      theme_color: "#0366d6",
      preview: {
        darker: "#1b1f23",
        dark: "#1f2428",
        darkless: "#2f363d",
        primary: "#0366d6",
        content: "#e1e4e8",
        info: "#79b8ff",
        success: "#34d058",
        warning: "#ffab70"
      }
    },
    {
      value: "github_light",
      label: "GitHub Light",
      description: "GitHub's classic light palette.",
      color_scheme: "light",
      theme_color: "#2188ff",
      preview: {
        darker: "#d1d5da",
        dark: "#e1e4e8",
        darkless: "#f6f8fa",
        primary: "#2188ff",
        content: "#24292e",
        info: "#0366d6",
        success: "#28a745",
        warning: "#e36209"
      }
    },
    {
      value: "nord",
      label: "Nord",
      description: "Arctic blue-gray contrast.",
      color_scheme: "dark",
      theme_color: "#88c0d0",
      preview: {
        darker: "#2e3440",
        dark: "#3b4252",
        darkless: "#434c5e",
        primary: "#88c0d0",
        content: "#e5e9f0",
        info: "#81a1c1",
        success: "#a3be8c",
        warning: "#ebcb8b"
      }
    },
    {
      value: "rose",
      label: "Rose Pine",
      description: "Rose Pine inspired dark palette.",
      color_scheme: "dark",
      theme_color: "#eb6f92",
      preview: {
        darker: "#191724",
        dark: "#1f1d2e",
        darkless: "#26233a",
        primary: "#eb6f92",
        content: "#e0def4",
        info: "#9ccfd8",
        success: "#31748f",
        warning: "#f6c177"
      }
    },
    {
      value: "rose_pine_dawn",
      label: "Rose Pine Dawn",
      description: "Rose Pine inspired light palette.",
      color_scheme: "light",
      theme_color: "#aa586f",
      preview: {
        darker: "#dfdad9",
        dark: "#f2e9e1",
        darkless: "#cecacd",
        primary: "#aa586f",
        content: "#575279",
        info: "#56949f",
        success: "#286983",
        warning: "#a35a00"
      }
    }
  ].freeze
  THEME_OPTION_BY_VALUE = THEME_OPTIONS.index_by { |theme| theme[:value] }.freeze

  class_methods do
    def theme_options
      THEME_OPTIONS.map(&:deep_dup)
    end

    def theme_metadata(theme_name)
      THEME_OPTION_BY_VALUE[theme_name.to_s] || THEME_OPTION_BY_VALUE[DEFAULT_THEME]
    end
  end
end

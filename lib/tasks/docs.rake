namespace :docs do
  desc "Generate static llms.txt and llms-full.txt files in public/"
  task generate_llms: :environment do
    puts "Generating llms.txt..."
    generate_llms_txt
    puts "✓ public/llms.txt"

    puts "Generating llms-full.txt..."
    generate_llms_full_txt
    puts "✓ public/llms-full.txt"

    puts "Done!"
  end

  def generate_llms_txt
    popular_editors = DocsController::POPULAR_EDITORS
    other_editors = DocsController::ALL_EDITORS - popular_editors

    lines = []
    lines << "# Hackatime"
    lines << ""
    lines << "> Hackatime is a free, open source coding time tracker built by Hack Club. It automatically tracks your coding time across 70+ editors and IDEs using existing WakaTime plugins. Privacy-first, completely free, with no premium features or paywalls."
    lines << ""
    lines << "For complete documentation in a single file, see [Full documentation](https://hackatime.hackclub.com/llms-full.txt)."
    lines << ""
    lines << "## Getting Started"
    lines << "- [Quick Start Guide](https://hackatime.hackclub.com/docs/getting-started/quick-start.md): Get up and running with Hackatime in under 5 minutes"
    lines << "- [Installation](https://hackatime.hackclub.com/docs/getting-started/installation.md): Add WakaTime plugins to your editor"
    lines << "- [Configuration](https://hackatime.hackclub.com/docs/getting-started/configuration.md): Advanced setup including GitHub integration, time zones, and privacy settings"
    lines << ""
    lines << "## Popular Editors"
    popular_editors.each do |name, slug|
      lines << "- [#{name}](https://hackatime.hackclub.com/docs/editors/#{slug}.md): Set up time tracking in #{name}"
    end
    lines << ""
    lines << "## Integrations"
    lines << "- [OAuth Apps](https://hackatime.hackclub.com/docs/oauth/oauth-apps.md): Build integrations with Hackatime using OAuth 2.0"
    lines << "- [API Documentation](https://hackatime.hackclub.com/api-docs): Interactive API reference for the Hackatime API"
    lines << ""
    lines << "## Optional"
    other_editors.each do |name, slug|
      lines << "- [#{name}](https://hackatime.hackclub.com/docs/editors/#{slug}.md): Set up time tracking in #{name}"
    end

    File.write(Rails.root.join("public", "llms.txt"), lines.join("\n") + "\n")
  end

  def generate_llms_full_txt
    docs_root = Rails.root.join("docs")
    all_editors = DocsController::ALL_EDITORS

    lines = []
    lines << "# Hackatime - Complete Documentation"
    lines << ""
    lines << "> Hackatime is a free, open source coding time tracker built by Hack Club. It automatically tracks your coding time across 70+ editors and IDEs using existing WakaTime plugins. Privacy-first, completely free, with no premium features or paywalls. Compatible with the WakaTime ecosystem -- just point your existing WakaTime plugin at Hackatime's API endpoint."
    lines << ""
    lines << "## Key Features"
    lines << ""
    lines << "- Automatic time tracking with no manual timers"
    lines << "- Language and project insights"
    lines << "- Leaderboards to compare with other Hack Club members"
    lines << "- Privacy-first: only metadata tracked, never actual code"
    lines << "- GitHub project linking for leaderboard visibility"
    lines << "- OAuth 2.0 API for third-party integrations"
    lines << "- Completely free with no paywalls"
    lines << ""
    lines << "## How It Works"
    lines << ""
    lines << "Hackatime works with any WakaTime plugin. Users configure their `~/.wakatime.cfg` file to point to Hackatime's API endpoint (`https://hackatime.hackclub.com/api/hackatime/v1`) instead of WakaTime's servers. All existing WakaTime editor plugins then send heartbeat data to Hackatime automatically."
    lines << ""
    lines << "## Getting Started"

    { "Quick Start" => "getting-started/quick-start.md",
      "Installation" => "getting-started/installation.md",
      "Configuration" => "getting-started/configuration.md" }.each do |title, path|
      file = docs_root.join(path)
      if File.exist?(file)
        lines << ""
        lines << "### #{title}"
        lines << File.read(file)
      else
        Rails.logger.warn("docs:generate_llms - missing #{path}")
      end
    end

    lines << ""
    lines << "## OAuth & API"

    oauth_file = docs_root.join("oauth", "oauth-apps.md")
    if File.exist?(oauth_file)
      lines << ""
      lines << "### OAuth Apps"
      lines << File.read(oauth_file)
    else
      Rails.logger.warn("docs:generate_llms - missing oauth/oauth-apps.md")
    end

    lines << ""
    lines << "## Editor Setup Guides"

    all_editors.each do |name, slug|
      file = docs_root.join("editors", "#{slug}.md")
      next unless File.exist?(file)

      lines << ""
      lines << "### #{name}"
      lines << File.read(file)
    end

    File.write(Rails.root.join("public", "llms-full.txt"), lines.join("\n") + "\n")
  end
end

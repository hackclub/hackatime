ENV["INERTIA_SYSTEM_TEST"] = "1"
ENV["VITE_RUBY_AUTO_BUILD"] = "false"

require "test_helper"

Capybara.register_driver :headless_playwright do |app|
  options = {
    browser_type: :chromium,
    headless: true,
    playwright_cli_executable_path: Rails.root.join("node_modules/.bin/playwright").to_s,
    args: [ "--no-sandbox", "--disable-dev-shm-usage" ],
    viewport: { width: 1400, height: 1400 }
  }
  options[:executablePath] = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?

  Capybara::Playwright::Driver.new(app, **options)
end

Capybara.server_host = "localhost"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthHelper

  parallelize workers: ENV.fetch("SYSTEM_TEST_WORKERS", ENV["CI"] ? 3 : 1).to_i, threshold: 1

  driven_by :headless_playwright
end

ENV["INERTIA_SYSTEM_TEST"] = "1"
ENV["VITE_RUBY_AUTO_BUILD"] ||= "true"

require "test_helper"

Capybara.register_driver :headless_chromium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")

  service = Selenium::WebDriver::Chrome::Service.new(
    path: ENV.fetch("CHROMEDRIVER_BIN", "/usr/bin/chromedriver")
  )

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthHelper

  driven_by :headless_chromium
end

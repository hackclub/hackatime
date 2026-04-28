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

  # (For CI pinning)
  if ENV["CHROME_BIN"].present?
    options.binary = ENV["CHROME_BIN"]
  end

  service = Selenium::WebDriver::Chrome::Service.new(
    path: ENV.fetch("CHROMEDRIVER_BIN", "/usr/bin/chromedriver")
  )

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthHelper

  # flaky chromedriver bug :/
  CHROMEDRIVER_NODE_ERROR = /Node with given id does not belong to the document/i

  driven_by :headless_chromium

  def run
    result = super
    return result unless chromedriver_node_error?(result)

    warn "Retrying #{self.class}##{name} after chromedriver node ownership error"

    self.failures = []
    self.assertions = 0
    super
  end

  private

  def chromedriver_node_error?(result)
    result.failures.any? do |failure|
      [ failure.message, failure.respond_to?(:error) ? failure.error&.message : nil ].any? do |message|
        message&.match?(CHROMEDRIVER_NODE_ERROR)
      end
    end
  end
end

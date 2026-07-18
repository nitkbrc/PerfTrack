# System specs drive a real headless Chrome. On machines without a system
# Chrome (e.g. WSL without sudo), we point Selenium at a user-local
# Chrome-for-Testing download instead; see ~/chrome-for-testing.
CHROME_DIR = File.expand_path("~/chrome-for-testing")
CHROME_BIN = File.join(CHROME_DIR, "chrome-headless-shell-linux64/chrome-headless-shell")
CHROMEDRIVER_BIN = File.join(CHROME_DIR, "chromedriver-linux64/chromedriver")
# Shared libraries (nss, nspr, asound) extracted locally because the WSL
# environment has no root access to install them system-wide.
CHROME_LIBS = File.join(CHROME_DIR, "libs/usr/lib/x86_64-linux-gnu")

# WSL + Windows-mounted filesystem is slow; give async assertions more room.
Capybara.default_max_wait_time = 10

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ] do |options|
      if File.exist?(CHROME_BIN)
        options.binary = CHROME_BIN
        Selenium::WebDriver::Chrome::Service.driver_path = CHROMEDRIVER_BIN
        ENV["LD_LIBRARY_PATH"] = [ CHROME_LIBS, ENV["LD_LIBRARY_PATH"] ].compact.join(":")
      end
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end
  end
end

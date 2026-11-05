require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    Warden.test_mode!
    # Browser in der Zeitzone der App, sonst ist „heute“ auf dem UTC-Runner nach
    # Mitternacht Schweizer Zeit im Browser noch gestern.
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: Time.zone.tzinfo.name)
  end
  teardown { Warden.test_reset! }
end

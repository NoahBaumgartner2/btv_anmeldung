require "test_helper"

class ClubSettingTest < ActiveSupport::TestCase
  test "text_color_on: dunkle Schrift auf hellen, weisse auf dunklen Vereinsfarben" do
    cs = ClubSetting.new
    assert_equal "#0b1220", cs.text_color_on("#fffb00")
    assert_equal "#ffffff", cs.text_color_on("#dc2626")
    assert_equal "#ffffff", cs.text_color_on("#1d4ed8")
  end
end

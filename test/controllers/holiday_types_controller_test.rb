require "test_helper"

class HolidayTypesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @holiday_type = holiday_types(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get holiday_types_url
    assert_response :success
  end

  test "should get new" do
    get new_holiday_type_url
    assert_response :success
  end

  test "should create holiday_type" do
    assert_difference("HolidayType.count") do
      post holiday_types_url, params: { holiday_type: { name: "Sportferien" } }
    end

    assert_redirected_to holiday_types_url
  end

  test "should get edit" do
    get edit_holiday_type_url(@holiday_type)
    assert_response :success
  end

  test "should update holiday_type" do
    patch holiday_type_url(@holiday_type), params: { holiday_type: { name: "Herbstferien (umbenannt)" } }
    assert_redirected_to holiday_types_url
  end

  test "should destroy holiday_type" do
    assert_difference("HolidayType.count", -1) do
      delete holiday_type_url(@holiday_type)
    end

    assert_redirected_to holiday_types_url
  end
end

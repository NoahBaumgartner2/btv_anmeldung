require "test_helper"

class HolidaysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @holiday_type = holiday_types(:one)
    @holiday = holidays(:one)
    sign_in users(:admin)
  end

  test "should get new" do
    get new_holiday_type_holiday_url(@holiday_type)
    assert_response :success
  end

  test "should create holiday" do
    assert_difference("Holiday.count") do
      post holiday_type_holidays_url(@holiday_type), params: { holiday: { start_date: "2028-10-02", end_date: "2028-10-17" } }
    end

    assert_redirected_to holiday_type_path(@holiday_type)
  end

  test "should get edit" do
    get edit_holiday_type_holiday_url(@holiday_type, @holiday)
    assert_response :success
  end

  test "should update holiday" do
    patch holiday_type_holiday_url(@holiday_type, @holiday), params: { holiday: { start_date: @holiday.start_date, end_date: @holiday.end_date } }
    assert_redirected_to holiday_type_path(@holiday_type)
  end

  test "should destroy holiday" do
    assert_difference("Holiday.count", -1) do
      delete holiday_type_holiday_url(@holiday_type, @holiday)
    end

    assert_redirected_to holiday_type_path(@holiday_type)
  end
end

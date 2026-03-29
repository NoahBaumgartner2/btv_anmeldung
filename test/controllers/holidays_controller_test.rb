require "test_helper"

class HolidaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @holiday = holidays(:one)
  end

  test "should get index" do
    get holidays_url
    assert_response :success
  end

  test "should get new" do
    get new_holiday_url
    assert_response :success
  end

  test "should create holiday" do
    assert_difference("Holiday.count") do
      post holidays_url, params: { holiday: { end_date: @holiday.end_date, start_date: @holiday.start_date, title: @holiday.title } }
    end

    assert_redirected_to holiday_url(Holiday.last)
  end

  test "should show holiday" do
    get holiday_url(@holiday)
    assert_response :success
  end

  test "should get edit" do
    get edit_holiday_url(@holiday)
    assert_response :success
  end

  test "should update holiday" do
    patch holiday_url(@holiday), params: { holiday: { end_date: @holiday.end_date, start_date: @holiday.start_date, title: @holiday.title } }
    assert_redirected_to holiday_url(@holiday)
  end

  test "should destroy holiday" do
    assert_difference("Holiday.count", -1) do
      delete holiday_url(@holiday)
    end

    assert_redirected_to holidays_url
  end
end

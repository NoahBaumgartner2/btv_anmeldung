require "test_helper"

class TermsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @term = terms(:one)
    sign_in users(:admin)
  end

  test "should get index" do
    get terms_url
    assert_response :success
  end

  test "should get new" do
    get new_term_url
    assert_response :success
  end

  test "should create term" do
    assert_difference("Term.count") do
      post terms_url, params: { term: { name: "WS2030", start_date: "2030-08-01", end_date: "2030-12-01" } }
    end

    assert_redirected_to terms_url
  end

  test "should not create term with invalid dates" do
    assert_no_difference("Term.count") do
      post terms_url, params: { term: { name: "WS2031", start_date: "2031-12-01", end_date: "2031-08-01" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_term_url(@term)
    assert_response :success
  end

  test "should update term" do
    patch term_url(@term), params: { term: { name: @term.name, start_date: @term.start_date, end_date: @term.end_date } }
    assert_redirected_to terms_url
  end

  test "should destroy term" do
    assert_difference("Term.count", -1) do
      delete term_url(@term)
    end

    assert_redirected_to terms_url
  end

  test "non-admin darf nicht auf terms zugreifen" do
    sign_out users(:admin)
    sign_in users(:parent_only)

    get terms_url
    assert_redirected_to root_path
  end
end

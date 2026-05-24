require "test_helper"

class CookieConsentsControllerTest < ActionDispatch::IntegrationTest
  test "POST /cookie_consent with consent=all sets cookie and returns 204" do
    post cookie_consent_path, params: { consent: "all" }

    assert_response :no_content
    assert_equal "all", cookies[:cookie_consent]
  end

  test "POST /cookie_consent with consent=necessary sets necessary cookie" do
    post cookie_consent_path, params: { consent: "necessary" }

    assert_response :no_content
    assert_equal "necessary", cookies[:cookie_consent]
  end

  test "POST /cookie_consent with unknown value defaults to necessary" do
    post cookie_consent_path, params: { consent: "unknown" }

    assert_response :no_content
    assert_equal "necessary", cookies[:cookie_consent]
  end

  test "POST /cookie_consent works without being logged in" do
    post cookie_consent_path, params: { consent: "all" }

    assert_response :no_content
  end
end

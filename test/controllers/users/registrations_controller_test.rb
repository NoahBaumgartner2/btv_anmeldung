require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # MailSetting initializer overrides delivery_method from SMTP_HOST env var;
    # reset to :test so no actual SMTP connection is attempted.
    ActionMailer::Base.delivery_method = :test
  end

  def valid_params(overrides = {})
    {
      user: {
        email: "new@example.com",
        password: "password123",
        password_confirmation: "password123",
        privacy_accepted: "1"
      }.merge(overrides)
    }
  end

  test "successful registration creates user and redirects" do
    assert_difference "User.count", 1 do
      post user_registration_url, params: valid_params
    end
    assert_response :redirect
  end

  test "registration fails without privacy_accepted" do
    assert_no_difference "User.count" do
      post user_registration_url, params: valid_params(privacy_accepted: "0")
    end
    assert_response :unprocessable_entity
  end

  test "newsletter subscription created when opt_in is set" do
    assert_difference "NewsletterSubscriber.count", 1 do
      post user_registration_url, params: valid_params(newsletter_opt_in: "1")
    end
    assert NewsletterSubscriber.exists?(email: "new@example.com")
  end

  test "newsletter error does not block registration" do
    original = NewsletterSubscriber.method(:find_or_initialize_by)
    NewsletterSubscriber.define_singleton_method(:find_or_initialize_by) do |*|
      raise StandardError, "Newsletter-Service nicht erreichbar"
    end

    assert_difference "User.count", 1 do
      post user_registration_url, params: valid_params(newsletter_opt_in: "1")
    end
    assert_response :redirect
  ensure
    NewsletterSubscriber.define_singleton_method(:find_or_initialize_by, original)
  end

  test "no newsletter subscriber created when opt_in is not set" do
    assert_no_difference "NewsletterSubscriber.count" do
      post user_registration_url, params: valid_params
    end
  end

  test "SMTP error on confirmation mail does not crash registration" do
    # Simulate production SMTP failure at the delivery layer so that
    # User#send_devise_notification's rescue block is actually exercised.
    raising_delivery = Class.new do
      def initialize(*); end
      def deliver!(mail)
        raise Net::SMTPAuthenticationError.new("535 5.7.0 Invalid login or password")
      end
    end
    ActionMailer::Base.add_delivery_method(:raising_smtp, raising_delivery)
    ActionMailer::Base.delivery_method = :raising_smtp

    assert_difference "User.count", 1 do
      post user_registration_url, params: valid_params
    end
    assert_response :redirect
    assert_match I18n.t("devise.registrations.confirmation_email_failed"), flash[:alert]
  ensure
    ActionMailer::Base.delivery_method = :test
  end
end

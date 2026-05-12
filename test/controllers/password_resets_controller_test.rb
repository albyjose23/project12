require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    ActionMailer::Base.deliveries.clear

    @user = User.create!(
      name: "Reset Faculty",
      email: "reset@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )
  end

  test "login page includes forgot password link" do
    get pages_login_url

    assert_response :success
    assert_match new_password_reset_path, response.body
    assert_match "Forgot Password?", response.body
  end

  test "should send password reset email for registered user" do
    post password_resets_url, params: {
      password_reset: {
        email: @user.email
      }
    }

    assert_redirected_to pages_login_url
    assert_equal "If that email is registered, a password reset link has been sent.", flash[:notice]

    @user.reload
    assert @user.reset_password_token.present?
    assert_in_delta Time.current.to_i, @user.reset_password_sent_at.to_i, 5
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match "Reset your QPaper password", ActionMailer::Base.deliveries.last.subject
    assert_match edit_password_reset_url(token: extract_token_from_last_email, host: "example.com"), ActionMailer::Base.deliveries.last.body.encoded
  end

  test "should not reveal whether an email exists" do
    post password_resets_url, params: {
      password_reset: {
        email: "missing@example.com"
      }
    }

    assert_redirected_to pages_login_url
    assert_equal "If that email is registered, a password reset link has been sent.", flash[:notice]
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "should reject invalid reset token" do
    get edit_password_reset_url(token: "bad-token")

    assert_redirected_to new_password_reset_url
    assert_equal "That password reset link is invalid or has expired.", flash[:alert]
  end

  test "should reject expired reset token" do
    token = @user.generate_password_reset_token!

    travel 31.minutes do
      get edit_password_reset_url(token: token)
      assert_redirected_to new_password_reset_url
      assert_equal "That password reset link is invalid or has expired.", flash[:alert]
    end
  end

  test "should reset password and invalidate token" do
    token = @user.generate_password_reset_token!

    patch password_reset_url(token: token), params: {
      user: {
        password: "NewPassword123",
        password_confirmation: "NewPassword123"
      }
    }

    assert_redirected_to pages_login_url
    assert_equal "Password updated successfully. Please sign in.", flash[:notice]

    @user.reload
    assert @user.authenticate("NewPassword123")
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at

    get edit_password_reset_url(token: token)
    assert_redirected_to new_password_reset_url
  end

  test "should keep token when password reset fails" do
    token = @user.generate_password_reset_token!

    patch password_reset_url(token: token), params: {
      user: {
        password: "NewPassword123",
        password_confirmation: "Mismatch123"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert @user.reset_password_token.present?
    assert @user.authenticate("Password123")
  end

  private

  def extract_token_from_last_email
    mail_body = ActionMailer::Base.deliveries.last.body.encoded
    mail_body.match(/token=([^"&\s<]+)/).captures.first
  end
end

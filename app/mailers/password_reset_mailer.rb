class PasswordResetMailer < ApplicationMailer
  def reset_email(user, token)
    @user = user
    @reset_url = edit_password_reset_url(token: token)

    mail(
      to: @user.email,
      subject: "Reset your QPaper password"
    )
  end
end

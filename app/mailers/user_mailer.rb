class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @login_url = pages_login_url

    mail(
      to: @user.email,
      subject: "Welcome to QPaper"
    )
  end
end

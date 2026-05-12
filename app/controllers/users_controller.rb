class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      reset_session
      session[:user_id] = @user.id
      begin
        UserMailer.welcome_email(@user).deliver_now
        redirect_to pages_dashboard_path, notice: "Account created successfully. A welcome email has been sent."
      rescue StandardError => e
        Rails.logger.error("Welcome email delivery failed for #{@user.email}: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.take(15).join("\n")) if e.backtrace.present?
        redirect_to pages_dashboard_path, alert: "Account created, but the welcome email could not be sent. Please check the mail settings."
      end
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render "pages/register", status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :department, :role, :password, :password_confirmation)
  end
end

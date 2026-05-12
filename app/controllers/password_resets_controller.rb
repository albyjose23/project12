class PasswordResetsController < ApplicationController
  before_action :load_user_from_token, only: [ :edit, :update ]

  def new; end

  def create
    if (user = User.find_by_email_for_authentication(password_reset_email))
      token = user.generate_password_reset_token!

      begin
        PasswordResetMailer.reset_email(user, token).deliver_now
      rescue StandardError => e
        Rails.logger.error("Password reset email delivery failed for #{user.email}: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.take(15).join("\n")) if e.backtrace.present?
      end
    end

    redirect_to pages_login_path, notice: "If that email is registered, a password reset link has been sent."
  end

  def edit; end

  def update
    if @user.update(password_params)
      @user.clear_password_reset_token!
      reset_session
      redirect_to pages_login_path, notice: "Password updated successfully. Please sign in."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_user_from_token
    @token = params[:token].to_s
    @user = User.find_by_password_reset_token(@token)
    return if @user

    redirect_to new_password_reset_path, alert: "That password reset link is invalid or has expired."
  end

  def password_reset_email
    params.dig(:password_reset, :email).to_s.strip.downcase
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end

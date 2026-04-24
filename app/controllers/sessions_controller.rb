class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params.dig(:session, :email).to_s.strip.downcase)

    if user&.authenticate(params.dig(:session, :password))
      session[:user_id] = user.id
      redirect_to pages_dashboard_path, notice: "Logged in successfully."
    else
      flash.now[:alert] = "Invalid email or password."
      render "pages/login", status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to pages_login_path, notice: "Logged out successfully."
  end
end

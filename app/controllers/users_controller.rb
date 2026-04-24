class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to pages_dashboard_path, notice: "Account created successfully."
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

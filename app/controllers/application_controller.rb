class ApplicationController < ActionController::Base

  include ApplicationHelper

  # Filters
  #----------------------------------------------------------------------
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  # Constants
  #----------------------------------------------------------------------
  NEW_USER = "?type=new_user"

  # Autentication methods
  #----------------------------------------------------------------------
  # Public: Check if the user has his own profile or not
  def authenticate_verify_user
    if !current_user.present?
      redirect_to request.referrer
    elsif !current_user.has_profile?
      redirect_to profile_dashboard_users_path + NEW_USER
    else
      return true
    end
  end

  # Devise alias methods
  #----------------------------------------------------------------------
  alias_method :devise_current_user, :current_user

end
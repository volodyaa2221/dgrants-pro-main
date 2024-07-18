class HomeController < ApplicationController

  # Static Page actions
  #----------------------------------------------------------------------
  # GET   /
  def index
    if current_user.present?
      flash[:error] = nil
      if current_user.has_profile?
        if current_user.time_span_in_DHMS[0] > 6.months / 1.day
          redirect_to profile_dashboard_users_path + NEW_USER
        else
          current_user.confirm! if current_user.confirmation_token.present?
          redirect_to dashboard_path
        end
      else
        redirect_to profile_dashboard_users_path + NEW_USER
      end
    else
      sign_out(:user)
    end
  end

  # GET /home/authorization(.:format)
  def authorization
    if current_user.present?
      redirect_to root_url
    end
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  # Authenticate client
  def authenticate_client!
    token = Digest::SHA2.hexdigest("Drugdev" + Date.today.to_s)
    error!('401 Unauthorized', 401) unless params[:token] == token
  end
end
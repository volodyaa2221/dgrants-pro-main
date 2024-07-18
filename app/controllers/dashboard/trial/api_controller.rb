class Dashboard::Trial::ApiController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user, only: :api_support
  before_action :authenticate_trial_level_user, only: :api_support

  # Trial API Support actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/api_support(.:format) 
  def api_support
    hashids = Hashids.new(Dgrants::Application::CONSTS[:cookie_name], 8, "abcdefghijklmnopqrstuvwxyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    @token  = "#{hashids.encode(current_user.id.to_s.to_i(16), 8).reverse}z#{hashids.encode(@trial.id.to_s.to_i(16), 8).reverse}"
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
    end
  end
end
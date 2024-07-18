class Dashboard::Trial::TrialsController < DashboardController
  include Dashboard::VpdHelper
  include Dashboard::TrialHelper
  
  before_action :get_trial, except: [:new, :create]
  
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user, only: [:new, :create]
  before_action :authenticate_trial_editable_user, only: :update
  before_action :authenticate_trial_level_user, except: [:new, :edit, :create, :udpate, :sites]

  # Trial actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/trials/new(.:format)
  def new
    @trial  = Trial.new
    @vpd = Vpd.find(params[:vpd_id]) if params[:vpd_id].present?
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/trial/trials(.:format)
  def create
    if params[:vpd_id].present?
      vpd = Vpd.find(params[:vpd_id])
    elsif params[:trial][:vpd_id].present?
      vpd = Vpd.find(params[:trial][:vpd_id])
    end
        
    trial = vpd.trials.build(trial_params)
    if trial.save
      ref_id = Account.new_ref_id
      vpd_name = vpd.name
      trial_name = trial.trial_id
      account = trial.build_account(ref_id: ref_id, vpd_name: vpd_name, trial_name: trial_name, vpd: vpd)
      if account.save
        data = {success:{msg: "Trial Added", name: trial.trial_id}}
      else
        trial.destroy
        data = {failure:{msg: account.errors.full_messages.first}}
      end
    else
      key, val = trial.errors.messages.first
      data = {failure:{msg: trial.errors.full_messages.first, element_id: "trial_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/trial/trials/:id/edit(.:format)
  def edit
    @user_sites = current_user.sites_of_trial(@trial)

    @sponsors = VpdSponsor.where(vpd_id: @trial.vpd_id, status: 1).order(name: :asc).map do |vpd_sponsor|
      [vpd_sponsor.name, vpd_sponsor.id.to_s]
    end

    vpd_sponsor = @trial.vpd_sponsor
    if vpd_sponsor.present?  &&  vpd_sponsor.status == 0
      @sponsors << [vpd_sponsor.name, vpd_sponsor.id.to_s]
      @sponsors = @sponsors.uniq
    end

    render layout: params[:type] != "ajax"
  end

  # PUT|PATCH /dashboard/trial/trials/:id(.:format) 
  def update
    if @trial.update_attributes(trial_params)
      render json: {success:{msg: "Trial Updated", text: "Your changes have been updated successfully.", name: @trial.trial_id}}      
    else
      key, val = @trial.errors.messages.first
      render json: {failure:{msg: @trial.errors.full_messages.first, element_id: "trial_#{key}"}}
    end
  end


  # Other Trial level actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/trials/:id/dashboard(.:format)
  def dashboard
    if current_user.trial_level_user?(@trial) && !@trial.vpd.trial_dashboard.blank?
      @dashboard_url = "#{@trial.vpd.trial_dashboard}&tid=#{@trial.id.to_s}"
      render layout: params[:type] != "ajax"
    else
      redirect_to edit_dashboard_trial_trial_path(@trial)
    end
  end

  # GET   /dashboard/trial/trials/:id/sites(.:format)
  def sites
    if current_user.trial_level_user?(@trial)
      @user_sites = Site.where(trial: @trial, status: 1)
    else
      @user_sites = current_user.sites_of_trial(@trial)
    end
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SiteDatatable.new(view_context, current_user) }
    end    
  end

  # GET   /dashboard/trial/trials/:id/should_forecast(.:format) 
  def should_forecast
    render json: {success:{forecasting_now: (@trial.forecasting_now ? 1 : 0), should_forecast: (@trial.should_forecast ? 1 : 0)}}
  end

  # GET  /dashboard/trial/trials/:id/sites_list_by_currency(.:format)
  def sites_list_by_currency
    @schedule_sites = @trial.sites_having_schedules_by_currency(params[:vpd_currency_id]).map do |site|
      [site.site_id, site.id.to_s]
    end
    @schedule_sites.unshift(["No Template", "0"])

    render layout: false
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def trial_params
    if params[:trial][:vpd_sponsor_id].present?
      vpd_sponsor = VpdSponsor.find(params[:trial][:vpd_sponsor_id])
      params[:trial][:sponsor_id] = vpd_sponsor.sponsor.id.to_s
    end
    params.require(:trial).permit(:trial_id, :title, :ctgov_nct, :max_patients, :indication, :phase, :sponsor_id, :vpd_sponsor_id, :event_log_mode)
  end
end
class Dashboard::Vpd::VpdsController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd,                     except: [:index, :new, :create]
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin,    except: [:update, :trials, :configs, :reports]
  before_action :authenticate_vpd_level_user, only:   [:update, :trials, :configs, :reports]

  # VPD actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/vpds(.:format)
  def index
    session[:vpd_id] = nil
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: VpdDatatable.new(view_context, current_user) }
    end
  end

  # GET   /dashboard/vpd/vpds/new(.:format)
  def new
    @vpd = Vpd.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/vpds(.:format)
  def create
    vpd = Vpd.new(vpd_params)    
    if vpd.save
      render json: {success:{msg: "VPD Added", name: vpd.name}}
    else
      key, val = vpd.errors.messages.first
      render json: {failure:{msg: vpd.errors.full_messages.first, element_id: "vpd_#{key}"}}
    end
  end

  # GET   /dashboard/vpd/vpds/:id/edit(.:format) 
  def edit
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/vpd/vpds/:id(.:format) 
  def update
    # Check MySQL DB Connection
    if params[:vpd][:db_host].present?
      results = Vpd.check_mysql_db_connection(params[:vpd][:db_host], params[:vpd][:username], params[:vpd][:password], params[:vpd][:db_name])
      if results[:connection_exist] && results[:db_exist]
        if @vpd.update_attributes(vpd_params)
          data = {success:{msg: "Vpd Updated", name: @vpd.name}}
        else
          key, val = @vpd.errors.messages.first
          data = {failure:{msg: @vpd.errors.full_messages.first, element_id: "vpd_#{key}"}}
        end
      elsif !results[:connection_exist]
        data = {failure:{msg: "Can't establish with those credentials", element_id: "popup"}}
      elsif !results[:db_exist]
        data = {failure:{msg: "Such database doesn't exist", element_id: "popup"}}
      end
    else
      if @vpd.update_attributes(vpd_params)
        data = {success:{msg: "Vpd Updated", name: @vpd.name}}
      else
        key, val = @vpd.errors.messages.first
        data = {failure:{msg: @vpd.errors.full_messages.first, element_id: "vpd_#{key}"}}
      end
    end

    render json: data
  end

  # Other VPD level actions
  #----------------------------------------------------------------------
  # GET /dashboard/vpds/:id/trials
  def trials
    session[:vpd_id] = @vpd.id.to_s
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: TrialDatatable.new(view_context, current_user, @vpd) }
    end
  end

  # GET   /dashboard/vpd/vpds/:id/configs(.:format)
  def configs
    render layout: params[:type] != "ajax"
  end

  # GET   /dashboard/vpd/vpds/:id/reports(.:format)
  def reports
    render layout: params[:type] != "ajax"
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def vpd_params
    params.require(:vpd).permit(:name, :auto_amount, :tier1_amount, :db_host, :db_name, :username, :password, :trial_dashboard, :site_dashboard)
  end
end
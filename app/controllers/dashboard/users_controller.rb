class Dashboard::UsersController < DashboardController

  skip_before_action :verify_authenticity_token, only: :create
  before_action :authenticate_verify_user, except: [:profile, :update_profile, :todo_tasks]
  before_action :authenticate_super_admin, except: [:trial_opts_for_vpd, :site_opts_for_trial, :profile, :update_profile, :todo_tasks, :task_site_opts, :task_vpd_countries_opts]

  # Super Admin actions
  #----------------------------------------------------------------------
  # GET   /dashboard/users(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: UserDatatable.new(view_context, current_user) }
    end
  end

  # GET   /dashboard/users/new(.:format) 
  def new
    @user_roles = user_roles
    @vpd_opts   = vpd_options
    @trial_opts = @vpd_opts.count > 0  ?  trial_options(@vpd_opts.first[1]) : []
    @site_opts  = @trial_opts.count > 0  ?  site_options(@trial_opts.first[1]) : []
    @user = User.new
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/users(.:format) 
  def create
    email       = params[:user][:email]
    p_role      = params[:user_role].to_i
    promote_to  = params[:user][:promote_to]

    vpd     = Vpd.find(params[:vpd]) if params[:vpd].present?
    trial   = Trial.find(params[:trial]) if params[:trial].present?

    if params[:sites].present? && params[:sites].count > 1
      data = {success: {sites:[], name: email}, failure: {sites: [], name: email}, is_site_invitation: true}
      sites = Site.find(params[:sites]) 
      sites.each do |site|
        json_result = invite_user(email.downcase, p_role, promote_to, vpd, trial, site)
        if json_result.has_key?(:success)
          data[:success][:sites] << site.site_id
        elsif json_result.has_key?(:failure)
          data[:failure][:sites] << site.site_id
        end
      end

      render json: data
    else
      site = Site.find(params[:sites][0]) if params[:sites].present?
      render json: invite_user(email.downcase, p_role, promote_to, vpd, trial, site)
    end
  end

  # GET   /dashboard/users/:id/edit(.:format) 
  def edit
    @user = params[:type].to_i==1 ? User.find(params[:id]) : Role.find(params[:id])
    @user_roles = user_roles
    @user_role  = params[:type].to_i==1 ? Role::ROLE[:super_admin] : @user.role

    @vpd_opts = vpd_options
    vpd = @vpd_opts.count > 0  ?  @vpd_opts.first[1] : nil
    vpd = (params[:type].to_i==0 && @user.role>Role::ROLE[:super_admin]) ? @user.vpd : vpd

    @trial_opts = @vpd_opts.count > 0  ?  trial_options(vpd) : []
    trial = @trial_opts.count > 0  ?  @trial_opts.first[1] : nil
    trial = (params[:type].to_i==0 && @user.role>Role::ROLE[:vpd_admin]) ? @user.trial : trial
    
    @site_opts = @trial_opts.count > 0  ?  site_options(trial) : []  end

  # PUT|PATCH   /dashboard/users/:id(.:format) 
  def update
    email       = params[:user][:email]
    p_role      = params[:role][:role].to_i
    promote_to  = params[:role][:promote_to]

    vpd   = Vpd.find(params[:role][:vpd]) if params[:role][:vpd].present?
    trial = Trial.find(params[:role][:trial]) if params[:role][:trial].present?
    site  = Site.find(params[:role][:site]) if params[:role][:site].present?

    render json: invite_user(email.downcase, p_role, promote_to, vpd, trial, site, params[:id])
  end

  # POST  /dashboard/users/:id/send_invite(.:format) 
  def send_invite
    user = User.find(params[:id])
    if user.present? && user.update_attributes(manager: current_user, role_type: user.member_type)
      if user.confirmation_token.present?
        user.send_confirmation_instructions
      else
        UserMailer.invited_super_admin(user).deliver
      end
      render json: {success:{msg: "Invitation has been sent successfully."}}
    else
      render json: {success:{msg: "User doesn't exist."}}
    end
  end

  # GET   /dashboard/users/trial_opts_for_vpd(.:format)
  def trial_opts_for_vpd
    @trial_opts = trial_options(params[:vpd])
    render layout: false
  end

  # GET   /dashboard/users/site_opts_for_trial(.:format)
  def site_opts_for_trial
    @site_opts = site_options(params[:trial])
    render layout: false
  end

  # GET   /dashboard/users/user_info(.:format)
  def user_info
    @user = User.find(params[:id])
    render layout: params[:type] != "ajax"
  end


  # Common actions
  #----------------------------------------------------------------------
  # GET /dashboard/user/profile
  # type - If type value is 'new_user' : profile page will be displayed without layout
  #                     not 'new_user' : profile page will be displayed with dashboard layout
  def profile
    if params[:id].present?
      @user = User.find(params[:id])
    else
      @user = current_user
    end
    @country_code = get_country
    
    redirect_to root_url unless @user.present?
    render layout: true
  end

  # PUT/PATCH /dashboard/update_profile
  def update_profile
    @user = User.find(params[:user_id])
    @user.confirm!
    # @user.skip_reconfirmation! 
    if params[:type] == "admin"  &&  current_user.super_admin?
      if @user.update_attributes(user_params)
        @user.confirm!
        if current_user == @user
          sign_in @user, bypass: true 
        end
        render json: {success: {msg: t("controllers.dashboard.update_profile.success_msg")}} and return
      else 
        render json: {failed: {msg: @user.errors.full_messages.first}} and return
      end
    else
      if @user.update_attributes(user_params)
        @user.confirm!
        if current_user == @user
          sign_in @user, bypass: true 
        end
        redirect_to dashboard_path
      else
        respond_to do |format|
          format.html { render action: :profile }
          format.json { render json: @user.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # GET   /dashboard/users/todo_tasks(.:format)
  def todo_tasks
    @user = current_user
    respond_to do |format|
      format.html {
        user_trials = @user.trials

        @trial_opts = user_trials.map { |trial| [trial.trial_id, trial.id] }
        @trial_opts.unshift(["All Trials", " "])

        @site_opts = task_site_options(user_trials)
        @country_opts = task_vpd_countries_options(user_trials)

        @task_type_opts = User::TASK_STATUS.map {|key, value| [key.to_s.gsub("_", " "), value]}
        @task_type_opts.unshift(["All Tasks", " "])

        render layout: params[:type] != "ajax" 
      }
      format.json { render json: TodoTasksDatatable.new(view_context, @user) }
    end
  end

  # GET   /dashboard/users/task_site_opts(.:format)
  def task_site_opts
    @site_opts = params[:trial].present? ? task_site_options([Trial.find(params[:trial])]) : task_site_options(current_user.trials)
    render layout: false
  end

  # GET   /dashboard/users/task_vpd_countries_opts(.:format)
  def task_vpd_countries_opts
    @country_opts = params[:trial].present? ? task_vpd_countries_options([Trial.find(params[:trial])]) : task_vpd_countries_options(current_user.trials)
    render layout: false
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def user_params
    params.require(:user).permit(:first_name, :last_name, :salutation, :password, :password_confirmation, 
                                 :organization, :position, :phone, :email, :country)    
  end

  def get_country
    unless @user.country.present? && !@user.country.blank?
      data = GeoIP.new(geoip_path).country(remote_ip)
      data[:country_code2]
    else
      @user.country
    end
  end

  def remote_ip
    if request.remote_ip == Dgrants::Application::CONSTS[:dev_ip]
      "67.169.73.113"
    else
      request.remote_ip
    end
  end

  # Returns "GeoIP.dat" file path
  def geoip_path
    "#{Rails.root}/db/res/GeoIP.dat"
  end
end
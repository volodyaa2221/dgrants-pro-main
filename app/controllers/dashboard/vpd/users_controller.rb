class Dashboard::Vpd::UsersController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Admin actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/users(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: VpdUserDatatable.new(view_context, current_user, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/users/new(.:format) 
  def new
    @user_roles = user_roles
    @user_roles.shift
    @trial_opts = trial_options(@vpd)
    @site_opts  = @trial_opts.count > 0  ?  site_options(@trial_opts.first[1]) : []
    @user = User.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/users(.:format) 
  def create
    email       = params[:user][:email]
    p_role      = params[:user_role].to_i
    promote_to  = params[:user][:promote_to]
    trial       = Trial.find(params[:trial]) if params[:trial].present?
    
    if params[:sites].present? && params[:sites].count > 1
      data = {success: {sites:[], name: email}, failure: {sites: [], name: email}, is_site_invitation: true}
      sites = Site.find(params[:sites]) 
      sites.each do |site|
        json_result = invite_user(email.downcase, p_role, promote_to, @vpd, trial, site)
        if json_result.has_key?(:success)
          data[:success][:sites] << site.site_id
        elsif json_result.has_key?(:failure)
          data[:failure][:sites] << site.site_id
        end
      end

      render json: data
    else
      site = Site.find(params[:sites][0]) if params[:sites].present?
      render json: invite_user(email.downcase, p_role, promote_to, @vpd, trial, site)
    end
  end

  # GET   /dashboard/vpd/:vpd_id/users/:id/edit(.:format) 
  def edit
    @user = Role.find(params[:id])
    @user_roles = user_roles.drop(1)
    
    @trial_opts = trial_options(@vpd)
    trial = @trial_opts.count > 0  ?  @trial_opts.first[1] : nil
    trial = @user.role>Role::ROLE[:vpd_admin] ? @user.trial : trial

    @site_opts  = @trial_opts.count > 0  ?  site_options(trial) : []
  end

  # PUT|PATCH   /dashboard/vpd/:vpd_id/users/:id(.:format) 
  def update
    email       = params[:user][:email]
    p_role      = params[:role][:role].to_i
    promote_to  = params[:role][:promote_to]

    trial = Trial.find(params[:role][:trial]) if params[:role][:trial].present?
    site  = Site.find(params[:role][:site]) if params[:role][:site].present?

    render json: invite_user(email.downcase, p_role, promote_to, @vpd, trial, site, params[:id])
  end

  # POST  /dashboard/vpd/:vpd_id/users/:id/send_invite(.:format) 
  def send_invite
    role = Role.find(params[:id])
    if role.present?
      role.update_attributes(invitation_sent_date: DateTime.now.to_date)
      user = User.find(role.user_id)
      if user.present? && user.update_attributes(manager: current_user, role_type: role.role)
        if user.confirmation_token.present?
          user.send_confirmation_instructions
        else
          UserMailer.invited_vpd_admin(user, @vpd).deliver
        end
        render json: {success:{msg: "Invitation has been sent successfully."}}
      else
        render json: {success:{msg: "User doesn't exist."}}
      end
    else 
      render json: {success:{msg: "Role doesn't exist."}}
    end
  end

  # GET   /dashboard/vpd/:vpd_id/sites_for_trial(.:format) 
  def sites_for_trial
    @sites = sites(params[:trial])
    render layout: false    
  end


  # Private Methods
  #----------------------------------------------------------------------
end
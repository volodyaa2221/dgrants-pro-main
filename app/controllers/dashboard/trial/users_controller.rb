class Dashboard::Trial::UsersController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Admin actions
  # ----------------------------------------
  # GET   /dashboard/trial/:trial_id/users(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: TrialUserDatatable.new(view_context, current_user, @trial) }
    end
  end

  # GET   /dashboard/trial/:trial_id/users/new(.:format) 
  def new
    respond_to do |format|
      format.js {
        @user_roles = user_roles.drop(2)
        @site_opts  = site_options(@trial)
        @user = User.new
      }
    end
  end

  # POST  /dashboard/trial/:trial_id/users(.:format) 
  def create
    email       = params[:user][:email]
    p_role      = params[:user_role].to_i
    promote_to  = params[:user][:promote_to]

    if params[:sites].present? && params[:sites].count > 1
      data = {success: {sites:[], name: email}, failure: {sites: [], name: email}, is_site_invitation: true}
      sites = Site.find(params[:sites]) 
      sites.each do |site|
        json_result = invite_user(email.downcase, p_role, promote_to, nil, @trial, site)
        if json_result.has_key?(:success)
          data[:success][:sites] << site.site_id
        elsif json_result.has_key?(:failure)
          data[:failure][:sites] << site.site_id
        end
      end

      render json: data
    else
      site = Site.find(params[:sites][0]) if params[:sites].present?
      render json: invite_user(email.downcase, p_role, promote_to, nil, @trial, site)
    end
  end

  # GET   /dashboard/trial/:trial_id/users/:id/edit(.:format) 
  def edit
    @user = Role.find(params[:id])
    @user_roles = user_roles.drop(2)
    @site_opts  = site_options(@trial)
  end

  # PUT|PATCH   /dashboard/trial/:trial_id/users/:id(.:format) 
  def update
    email       = params[:user][:email]
    p_role      = params[:role][:role].to_i
    promote_to  = params[:role][:promote_to]

    site        = Site.find(params[:role][:site]) if params[:role][:site].present?

    render json: invite_user(email.downcase, p_role, promote_to, nil, @trial, site, params[:id])
  end
  
  # POST  /dashboard/trial/:trial_id/users/:id/send_invite(.:format) 
  def send_invite
    role = Role.find(params[:id])
    if role.present?
      role.update_attributes(invitation_sent_date: DateTime.now.to_date)
      user = User.find(role.user_id)
      if user.present? && user.update_attributes(manager: current_user, role_type: role.role)
        if user.confirmation_token.present?
          user.send_confirmation_instructions
        else
          UserMailer.added_to_new_trial(user, @trial, role.full_role_label).deliver
        end
        render json: {success:{msg: "Invitation has been sent successfully."}}
      else
        render json: {success:{msg: "User doesn't exist."}}
      end
    else 
      render json: {success:{msg: "Role doesn't exist."}}
    end
  end
end
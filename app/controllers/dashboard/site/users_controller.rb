class Dashboard::Site::UsersController < DashboardController
  include Dashboard::SiteHelper

  skip_before_action :authenticate_super_admin

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_editable_user, except: :index
  before_action :authenticate_site_level_user, only: :index

  # Site User(Admin) actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/users(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SiteUserDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/users/new(.:format) 
  def new
    @user = User.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/users(.:format) 
  def create
    email       = params[:user][:email]
    p_role      = params[:user][:role].to_i
    promote_to  = params[:user][:promote_to]

    render json: invite_user(email.downcase, p_role, promote_to, nil, nil, @site)
  end

  # GET   /dashboard/site/:site_id/users/:id/edit(.:format) 
  def edit
    @user = Role.find(params[:id])
  end

  # PUT|PATCH   /dashboard/site/:site_id/users/:id(.:format) 
  def update
    p_role = params[:role][:role].to_i
    role   = Role.find(params[:id])
    if role.update_attributes(role: p_role)
      data = {success:{msg: "Edit Site User", id: role.id.to_s, name: role.email}}
    else
      key, val = role.errors.messages.first
      data = {failure:{msg: role.errors.full_messages.first, element_id: "role_#{key}"}}
    end

    render json: data
  end

  # POST  /dashboard/site/:site_id/users/:id/send_invite(.:format)
  def send_invite
    role = Role.find(params[:id])
    if role.present?
      role.update_attributes(invitation_sent_date: DateTime.now.to_date)
      user = User.find(role.user_id)
      if user.present? && user.update_attributes(manager: current_user, role_type: role.role)
        if user.confirmation_token.present?
          user.send_confirmation_instructions
        else
          UserMailer.added_to_new_site(user, @site, role.full_role_label).deliver
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
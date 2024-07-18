class Dashboard::Vpd::ApproversController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user, except: :provinces

  # Other VPD level actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/approvals(.:format) 
  def approvals
    render layout: params[:type] != "ajax"
  end

  # GET   /dashboard/vpd/:vpd_id/approvers(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: VpdApproverDatatable.new(view_context, current_user, @vpd, params[:approver_type]) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/approvers/new(.:format)
  def new
    @approver = VpdApprover.new
    @approver.type = params[:approver_type]
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/approvers(.:format) 
  def create
    user = User.where(email: params[:email], status: 1)
    if user.exists?
      user = user.first
      role = Role.where(user: user, status: 1, vpd: @vpd)
      if role.exists?
        role = role.first
        approver = VpdApprover.new(user: user, role: role, vpd: @vpd, type: params[:vpd_approver][:type])
        if approver.save
          render json: {success:{msg: "Approver Added", name: user.name}}
        else
          key, val = approver.errors.messages.first
          render json: {failure:{msg: approver.errors.full_messages.first, element_id: "email"}}
        end
      else
        render json: {failure:{msg: "That user doesn't exist in this VPD", element_id: "email"}}
      end
    else
      render json: {failure:{msg: "That user doesn't exist in system", element_id: "email"}}
    end
  end


  # Private methods
  #----------------------------------------------------------------------
  private
end
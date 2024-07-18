class DashboardController < ApplicationController
  include DashboardHelper

  before_action :authenticate_user!
  before_action :authenticate_verify_user
  
  layout "dashboard"

  # General actions
  #----------------------------------------------------------------------
  # GET /dashboard/index
  def index
    @user = current_user
    respond_to do |format|
      format.html{ render layout: params[:type] != "ajax" }
      format.json{ render json: TrialDatatable.new(view_context, @user, nil) }
    end
  end

  # Public actions
  #----------------------------------------------------------------------
  # POST /dashboard/update_status 
  def update_status
    model = params[:object].constantize
    object = model.find(params[:status_id])
    if object.update_attributes(status: params[:status])
      render json: {success:{msg: "Updated #{params[:object]}", id: object.id.to_s}}
    else      
      render json: {failure:{msg: object.errors.full_messages.first}}
    end
  end


  # Private methods
  #----------------------------------------------------------------------
end
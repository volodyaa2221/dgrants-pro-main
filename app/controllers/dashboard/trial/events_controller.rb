class Dashboard::Trial::EventsController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Event actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/events(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: EventTypeDatatable.new(view_context, current_user, @trial, params[:type]) }
    end
  end

  # GET   /dashboard/trial/:trial_id/events/new(.:format) 
  def new
    type = params[:type]
    @event = TrialEvent.new
    @event.type = type
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/trial/:trial_id/events(.:format) 
  def create
    trial_event = @trial.trial_events.build(event_params)
    if trial_event.save
      data = {success:{msg: "Event Added", name: trial_event.event_id, type: trial_event.type}}
    else
      key, val = trial_event.errors.messages.first
      data = {failure:{msg: trial_event.errors.full_messages.first, element_id: "trial_event_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/trial/:trial_id/events/:id/edit(.:format) 
  def edit
    @event = TrialEvent.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/trial/:trial_id/events/:id(.:format) 
  def update
    trial_event = TrialEvent.find(params[:id])
    if trial_event.update_attributes(event_params)
      data = {success:{msg: "Event Updated", name: trial_event.event_id, type: trial_event.type}}
    else
      key, val = trial_event.errors.messages.first
      data = {failure:{msg: trial_event.errors.full_messages.first, element_id: "trial_event_#{key}"}}
    end

    render json: data
  end

  # Other actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/events/change_order(.:format)
  def change_order
    fromOrder = params[:fromPosition].to_i-1
    toOrder   = params[:toPosition].to_i-1
    trial_event = TrialEvent.find(params[:id].gsub("row_", ""))
    
    temp_order = params[:direction] == "forward" ? fromOrder+1 : fromOrder-1
    order1 = [temp_order, toOrder].min
    order2 = [temp_order, toOrder].max
    sign   = params[:direction] == "forward" ? -1 : 1

    TrialEvent.where("trial_id = #{@trial.id} AND type = #{trial_event.type} AND `order` >= #{order1} AND `order` <= #{order2}").each do |e|
      e.increment(:order, sign)
      e.save
    end

    if trial_event.update_attributes(order: toOrder)
      data = {success:{msg: "Option order changed successfully."}}
    else
      data = {failure:{msg: "Faild in changing option's order."}}
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  def event_params
    if action_name == "create"
      max_order = TrialEvent.max_order_in_fields(@trial, params[:trial_event][:type])
      if max_order.present?
        max_order += 1
      else
        max_order = 0
      end
      params[:trial_event][:order] = max_order
    end

    if params[:trial_event][:dependency].nil? || params[:trial_event][:dependency].blank?
      params[:trial_event][:dependency] = nil
      params[:trial_event][:days] = 0
    else
      params[:trial_event][:dependency_id] = params[:trial_event][:dependency]
    end
    params[:trial_event][:vpd_id] = @trial.vpd.id
    params.require(:trial_event).permit(:event_id, :type, :description, :dependency_id, :days, :order).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:trial_event][:vpd_id]
    end
  end
end
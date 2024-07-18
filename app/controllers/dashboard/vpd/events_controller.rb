class Dashboard::Vpd::EventsController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Event actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/events(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: EventTypeDatatable.new(view_context, current_user, @vpd, params[:type]) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/events/new(.:format) 
  def new
    type = params[:type]
    @event = VpdEvent.new
    @event.type = type
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/events(.:format) 
  def create
    vpd_event = @vpd.vpd_events.build(event_params)
    if vpd_event.save
      data = {success:{msg: "Event Added", name: vpd_event.event_id, type: vpd_event.type}}
    else
      key, val = vpd_event.errors.messages.first
      data = {failure:{msg: vpd_event.errors.full_messages.first, element_id: "vpd_event_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/vpd/:vpd_id/events/:id/edit(.:format)
  def edit
    @event = VpdEvent.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/vpd/:vpd_id/events/:id(.:format) 
  def update
    vpd_event = VpdEvent.find(params[:id])
    if vpd_event.update_attributes(event_params)
      data = {success:{msg: "Event Updated", name: vpd_event.event_id, type: vpd_event.type}}
    else
      key, val = vpd_event.errors.messages.first
      data = {failure:{msg: vpd_event.errors.full_messages.first, element_id: "vpd_event_#{key}"}}
    end

    render json: data
  end

  # Other actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/events/change_order(.:format)
  def change_order
    fromOrder = params[:fromPosition].to_i-1
    toOrder   = params[:toPosition].to_i-1
    vpd_event = VpdEvent.find(params[:id].gsub("row_", ""))
    
    temp_order = params[:direction] == "forward" ? fromOrder+1 : fromOrder-1
    order1 = [temp_order, toOrder].min
    order2 = [temp_order, toOrder].max
    sign   = params[:direction] == "forward" ? -1 : 1

    VpdEvent.where("vpd_id = #{@vpd.id} AND type = #{vpd_event.type} AND `order` >= #{order1} AND `order` <= #{order2}").each do |e|
      e.increment(:order, sign)
      e.save
    end

    if vpd_event.update_attributes(order: toOrder)
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
      max_order = VpdEvent.max_order_in_fields(@vpd, params[:vpd_event][:type])
      if max_order.present?
        max_order += 1
      else
        max_order = 0
      end
      params[:vpd_event][:order] = max_order
    end

    if params[:vpd_event][:dependency].nil? || params[:vpd_event][:dependency].blank?
      params[:vpd_event][:dependency_id] = nil
      params[:vpd_event][:days] = 0
    else
      params[:vpd_event][:dependency_id] = params[:vpd_event][:dependency]
    end
    params.require(:vpd_event).permit(:event_id, :type, :description, :dependency_id, :days, :order)
  end
end
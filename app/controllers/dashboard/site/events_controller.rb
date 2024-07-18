class Dashboard::Site::EventsController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :event_descriptions,                      only: :new
  before_action :patient_ids,                             only: [:new, :edit]
  before_action :patient_event_ids,                       only: [:new, :edit]
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:edit, :update, :destroy]
  before_action :authenticate_site_editable_user,         except: :index
  before_action :authenticate_site_level_user,            only: :index

  # Site Event actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/events(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: EventLogDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/events/new(.:format) 
  def new
    @trial_events = TrialEvent.where(trial_id: @site.trial_id, status: 1)
    @selected_trial_event = @trial_events.exists? ? @trial_events.first.event_id : nil

    pt_start_event_params = @site.last_patient_id_params(false)

    @event = SiteEvent.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/events(.:format) 
  def create
    site_event = @site.site_events.build(event_params)
    if site_event.save
      data = {success:{msg: "Event Logged", name: site_event.event_id, type: site_event.type}}
    else
      key, val = site_event.errors.messages.first
      if key == :event_log_id
        old_event = site_event.duplicated_site_events_by_event_log_id(false).first
        if old_event.present?
          if old_event.event_id != site_event.event_id
            data = {failure:{msg: site_event.errors.full_messages.first, element_id: "site_event_#{key}"}}
          elsif old_event.patient_id==site_event.patient_id && 
            old_event.description==site_event.description && old_event.happened_at==site_event.happened_at
            data = {success:{msg: "Event Logged", name: site_event.event_id, type: site_event.type}}
          else
            old_event.disable_transactions
            if old_event.update_attributes(event_id: site_event.event_id, patient_id: site_event.patient_id, happened_at: site_event.happened_at, 
                                          happened_at_text: site_event.happened_at_text, description: site_event.description)
              old_event.after_create_event
              data = {success:{msg: "Event Logged", name: site_event.event_id, type: site_event.type}}
            else
              key, val = old_event.errors.messages.first
              data = {failure:{msg: old_event.errors.full_messages.first, element_id: "site_event_#{key}"}}
            end
          end
        else
          data = {failure:{msg: site_event.errors.full_messages.first, element_id: "site_event_#{key}"}}
        end
      else
        data = {failure:{msg: site_event.errors.full_messages.first, element_id: "site_event_#{key}"}}
      end
    end

    render json: data
  end

  # GET   /dashboard/site/:site_id/events/:id/edit(.:format) 
  def edit
    @event = SiteEvent.find(params[:id])
    @event_type = 0
    if @event.type == VpdEvent::TYPE[:patient_event]
      @event_type = (@event.event_id == "CONSENT") ? 1 : 2
    end
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/site/:site_id/events/:id(.:format) 
  def update
    site_event = SiteEvent.find(params[:id])
    if site_event.update_attributes(description: params[:site_event][:description])
      data = {success:{msg: "Event Updated", name: site_event.event_id, type: site_event.type}}
    else
      key, val = site_event.errors.messages.first
      data = {failure:{msg: site_event.errors.full_messages.first, element_id: "site_event_#{key}"}}
    end

    render json: data
  end

  # DELETE  /dashboard/site/:site_id/events/:id(.:format) 
  def destroy
    event = SiteEvent.find(params[:id])
    if event.update_attributes(status: 0)
      event.disable_transactions
      data = {success:{msg: "Event Deleted", type: event.type}}
    else
      key, val = event.errors.messages.first
      data = {failure:{msg: "Failed to disable event log", details: val}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def event_descriptions
    @event_descriptions = {}
    TrialEvent.where(trial_id: @site.trial_id, status: 1).each do |trial_event|
      @event_descriptions[trial_event.event_id.to_sym] = trial_event.description
    end
  end

  def patient_ids
    @patient_ids = SiteEvent.where("site_id = #{@site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND event_id = 'CONSENT' AND status = 1").map(&:patient_id)
  end

  def patient_event_ids    
    @patient_event_ids = TrialEvent.where(trial_id: @site.trial_id, type: VpdEvent::TYPE[:patient_event], status: 1).map(&:event_id)
  end

  def event_params
    trial_event = TrialEvent.where(trial_id: @site.trial_id, event_id: params[:site_event][:event_id]).first
    params[:site_event][:happened_at] = params[:site_event][:happened_at].present? ? DateTime.strptime(params[:site_event][:happened_at], "%m/%d/%Y").to_date : nil
    params[:site_event][:happened_at_text] = params[:site_event][:happened_at].present? ? params[:site_event][:happened_at].strftime("%m/%d/%Y") : nil
    params[:site_event][:type]         = trial_event.type
    params[:site_event][:source]       = SiteEvent::SOURCE[:manual]
    params[:site_event][:author]       = current_user.name.blank? ? current_user.email : current_user.name
    params[:site_event][:vpd_id]       = @site.vpd.id
    params[:site_event][:event_log_id] = @site.new_event_log_id unless params[:site_event][:event_log_id].present?

    if params[:action] == "create" && @site.trial.event_log_mode == 1
      params[:site_event][:approved] = current_user.tcm_level_user?(@site) ? 1 : 0
    end

    params.require(:site_event).permit(:event_id, :type, :description, :patient_id, :event_log_id, :happened_at, :happened_at_text, :source, :author, :approved).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:site_event][:vpd_id]
    end
  end
end
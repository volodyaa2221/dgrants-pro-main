class Dashboard::Trial::SiteEventsController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :event_descriptions,                only: :new
  before_action :patient_event_ids,                 only: [:new, :site_options]
  before_action :authenticate_verify_user           
  before_action :authenticate_trial_editable_user,  except: [:index, :update_status]
  before_action :authenticate_trial_level_user,     only: :index

  # Site Event actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/site_events(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: EventLogDatatable.new(view_context, current_user, @trial) }
    end
  end

  # GET   /dashboard/trial/:trial_id/site_events/new(.:format) 
  def new
    @sites  = Site.where(trial: @trial, status: 1)
    @site   = @sites.first
    patient_ids(@site)
    @selected_site_id = @site.present? ? @site.id.to_s : nil
    @trial_events = TrialEvent.where(trial: @trial, status: 1)
    @selected_trial_event = @trial_events.exists? ? @trial_events.first.event_id : nil

    @event = SiteEvent.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # GET   /dashboard/trial/:trial_id/site_events/site_options(.:format) 
  def site_options
    @site = Site.where(trial: @trial, status: 1, id: params[:site_id]).first
    patient_ids(@site)
    patient_id_opts = @patient_ids.map do |patient_id|
      "<option value='#{patient_id}'>#{patient_id}</option>".html_safe
    end

    render json: {success:{patient_ids: patient_id_opts}}
  end

  # POST  /dashboard/trial/:trial_id/site_events(.:format) 
  def create
    @site = Site.where(trial: @trial, status: 1, id: params[:site_event][:site_id]).first
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

  # GET   /dashboard/trial/:trial_id/site_events/:id/edit(.:format)  
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

  # PUT|PATCH   /dashboard/trial/:trial_id/site_events/:id(.:format) 
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

  # DELETE  /dashboard/trial/:trial_id/site_events/:id(.:format)
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

  # POST  /dashboard/trial/:trial_id/site_events/:site_event_id/update_status(.:format)
  def update_status
    event = SiteEvent.find(params[:event_id])
    status = params[:approved].to_i

    if status == 0 || event.approved
      render json: {failure: {msg: "Event can't be disapproved."}}
    else
      event.assign_attributes(approved: status)
      if event.present? && event.save
        event.after_create_event
        render json: {success:{msg: "Event approved successfully.", id: event.id.to_s}}
      else
        render json: {failure:{msg: event.errors.full_messages.first}}
      end
    end
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def event_descriptions
    @event_descriptions = {}
    TrialEvent.where(trial: @trial, status: 1).each do |trial_event|
      @event_descriptions[trial_event.event_id.to_sym] = trial_event.description
    end
  end

  def patient_event_ids
    @patient_event_ids = TrialEvent.where(trial: @trial, type: VpdEvent::TYPE[:patient_event], status: 1).map(&:event_id)
  end

  def patient_ids(site)
    @patient_ids = site.present? ? SiteEvent.where("site_id = #{@site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND event_id = 'CONSENT' AND status = 1").map(&:patient_id) : []
  end

  def event_params
    trial_event = TrialEvent.where(trial_id: @site.trial_id, event_id: params[:site_event][:event_id]).first
    params[:site_event][:happened_at] = params[:site_event][:happened_at].present? ? DateTime.strptime(params[:site_event][:happened_at], "%m/%d/%Y").to_date : nil
    params[:site_event][:happened_at_text] = params[:site_event][:happened_at].present? ? params[:site_event][:happened_at].strftime("%m/%d/%Y") : nil
    params[:site_event][:type]         = trial_event.type
    params[:site_event][:source]       = SiteEvent::SOURCE[:manual]
    params[:site_event][:author]       = current_user.name.blank? ? current_user.email : current_user.name
    params[:site_event][:vpd_id]       = @trial.vpd.id
    params[:site_event][:event_log_id] = @site.new_event_log_id unless params[:site_event][:event_log_id].present?

    params.require(:site_event).permit(:event_id, :type, :description, :patient_id, :event_log_id, :happened_at, :happened_at_text, :source, :author).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:site_event][:vpd_id]
    end
  end
end
class ApiController < ApplicationController
  skip_before_filter :verify_authenticity_token

  before_action :check_params

  # API actions
  #----------------------------------------------------------------------
  # GET   /api/v1/get_defs(.:format) 
  # Get all available trial event types 
  def get_defs
    if @user.present? && @trial.present?
      static_events = TrialEvent.where(trial: @trial, status: 1, type: VpdEvent::TYPE[:single_event]).map{|trial_event| trial_event.event_id}
      patient_events = TrialEvent.where(trial: @trial, status: 1, type: VpdEvent::TYPE[:patient_event]).map{|trial_event| trial_event.event_id}
      @data = {status: "ok", available_events: {static_events: static_events, patient_events: patient_events}}
    end
    render json: @data
  end

  # GET   /api/v1/get_logged_patient_ids(.:format)
  #  Gets available patient_ids to log events
  def get_logged_patient_ids
    if @site.nil?
      @data = {status: "fail", errors: "invalid site"}
    else
      @data = {status: "ok", logged_patient_ids: SiteEvent.logged_patient_ids(@site)}
    end
    render json: @data
  end

  # POST  /api/v1/log(.:format) 
  # Create event log(static or patient)
  def log
    if @site.nil?
      @data = {status: "fail", errors: "invalid site"}
    elsif params[:event_id].nil?
      @data = {status: "fail", errors: "invalid event_id"}
    else
      if @trial_event.type == VpdEvent::TYPE[:patient_event]  &&  params[:patient_ID].nil? 
        @data = {status: "fail", errors: "invalid patient_ID"}
      else
        site_event = @site.site_events.build(event_params)
        if site_event.type == VpdEvent::TYPE[:patient_event] && site_event.event_id != "CONSENT" && !SiteEvent.check_pt_start_by_patient_id(@site.id, site_event.patient_id)
          @data = {status: "ok", result: "Can't log visits without CONSENT!"}
        else
          if site_event.save
            @data = {status: "ok", result: "Event Logged"}
          else
            key, val = site_event.errors.messages.first
            if key == :event_log_id
              old_event = site_event.duplicated_site_events_by_event_log_id(false).first
              if old_event.present?
                if old_event.event_id != site_event.event_id
                  @data = {status: "fail", errors: site_event.errors.full_messages.first}
                elsif old_event.patient_id==site_event.patient_id && 
                  old_event.description==site_event.description && old_event.happened_at==site_event.happened_at
                  @data = {status: "ok", result: "Event Logged"}
                else
                  old_event.disable_transactions
                  if old_event.update_attributes(event_id: site_event.event_id, patient_id: site_event.patient_id, happened_at: site_event.happened_at, 
                                                happened_at_text: site_event.happened_at_text, description: site_event.description)
                    old_event.after_create_event
                    @data = {status: "ok", result: "Event Logged"}
                  else
                    key, val = old_event.errors.messages.first
                    @data = {status: "fail", errors: old_event.errors.full_messages.first}
                  end
                end
              else
                @data = {status: "fail", errors: site_event.errors.full_messages.first}
              end
            else
              @data = {status: "fail", errors: site_event.errors.full_messages.first}
            end
          end
        end
      end
    end
    render json: @data
  end

  # DELETE  /api/v1/rev(.:format)
  # Reverse event log(static or patient)
  def rev
    if @site.nil?
      @data = {status: "fail", errors: "invalid site"}
    else
      if params[:event_id].present? && params[:patient_ID].present?
        events = SiteEvent.where(site: @site, status: 1, event_id: params[:event_id], patient_id: params[:patient_ID])
      elsif params[:event_id].present? && params[:patient_ID].nil?
        events = SiteEvent.where(site: @site, status: 1, event_id: params[:event_id])
      elsif params[:event_id].nil? && params[:patient_ID].present?
        events = SiteEvent.where(site: @site, status: 1, patient_id: params[:patient_ID])
      else
        events = SiteEvent.where(site: @site, status: 1)
      end

      success = fail = 0
      failed_reason = []
      events.each do |event|
        if event.update_attributes(status: 0)
          event.disable_transactions
          success+=1
        else
          fail+=1
          key, val = event.errors.messages.first
          failed_reason << val
        end
      end
          
      if fail == 0
        @data = {status: "ok", result: "#{success} events were reversed"}
      else
        @data = {status: "fail", result: "#{success} events were reversed and #{fail} events failed", errors: failed_reason}
      end
    end
    render json: @data
  end

  # GET   /api/v1/dump(.:format) 
  def dump
    if @trial.present?
      if @site.nil?
        site_ids = Site.where(trial: @trial, status: 1).map(&:id)
        events = SiteEvent.where("site_id IN #{site_ids.join(",")} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").order(happened_at: :desc, created_at: :desc)
      else
        events = SiteEvent.where("site_id = #{@site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").order(happened_at: :desc, created_at: :desc)
      end
      events = events.map do |e|
        status = e.status == 1  ?  "Active" : "Reversed"
        {event_id: e.event_id, description: e.description, patient_id: e.patient_id, happened_at: e.happened_at_text, 
        source: e.source, status: status, author: e.author, co_author: e.co_author}
      end
      @data = {status: "ok", result: events}
    end
    render json: @data
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  
  def check_params
    if params[:token].nil?
      @data = {status: "fail", errors: "invalid security token"}
      return
    end

    hashids = Hashids.new(Dgrants::Application::CONSTS[:cookie_name], 8, "abcdefghijklmnopqrstuvwxyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    tokens  = params[:token].split('z')
    code    = hashids.decode(tokens[0].reverse)
    if code.blank?
      @data = {status: "fail", errors: "invalid security token"}
      return
    end
    user_id = code[0].to_s(16)
    users   = User.where(id: user_id)
    unless users.exists?
      @data = {status: "fail", errors: "invalid user"}
      return
    end
    @user   = users.first

    code    = hashids.decode(tokens[1].reverse)
    if code.blank?
      @data = {status: "fail", errors: "invalid security token"}
      return
    end
    trial_id = code[0].to_s(16)
    trials   = Trial.where(id: trial_id)
    unless trials.exists?
      @data = {status: "fail", errors: "invalid trial"}
      return
    end
    @trial = trials.first

    unless @user.trial_editable?(@trial)
      @data = {status: "fail", errors: "you don't have access to this trial"}
      @user = @trial = nil
      return
    end

    if params[:s].present?
      sites = Site.where(trial: @trial, site_id: params[:s], status: 1)
      @site = sites.first if sites.exists?
    end

    if params[:event_id].present?
      @trial_event = TrialEvent.where(trial: @trial, event_id: params[:event_id]).first
    end
  end

  def event_params
    params[:happened_at] = params[:datetime].present? ? DateTime.strptime(params[:datetime], "%Y-%m-%d").to_date : nil
    params[:happened_at_text] = params[:happened_at].present? ? params[:happened_at].strftime("%m/%d/%Y") : nil
    params[:type] = @trial_event.type
    params[:description] = @trial_event.description
    params[:source] = SiteEvent::SOURCE[:api]
    params[:author] = @user.name.blank? ? @user.email : @user.name
    params[:patient_id]   = params[:patient_ID].present? ? params[:patient_ID] : nil
    params[:vpd_id]       = @trial.vpd.id
    params[:event_log_id] = @site.try(:new_event_log_id) unless params[:event_log_id].present?

    params.permit(:event_id, :type, :description, :patient_id, :event_log_id, :happened_at, :happened_at_text, :source, :author, :vpd_id)
  end
end
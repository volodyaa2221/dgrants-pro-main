class Dashboard::Trial::EntriesController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Payment Entry actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/entries?schedule={schedule_id}&entry_type=0/1(.:format) 
  def index
    schedule = TrialSchedule.find(params[:schedule])
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: TrialEntryDatatable.new(view_context, current_user, @trial, schedule, params[:entry_type].to_i) }
    end
  end

  # GET   /dashboard/trial/:trial_id/entries/new(.:format)?schedule={schedule_id}&entry_type=0/1 
  def new
    @type = params[:entry_type].to_i
    @schedule = TrialSchedule.find(params[:schedule])
    @tax_rate = @schedule.tax_rate
    @holdback_rate = @schedule.holdback_rate
    @event_ids = event_ids(@type)
    @categories = @trial.vpd.vpd_ledger_categories.order(name: :asc).map{|cat| [cat.name, cat.id.to_s]}
    @categories.unshift(["UNSPECIFIED", nil])
    @entry = TrialEntry.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/trial/:trial_id/entries(.:format)
  def create
    trial_schedule = TrialSchedule.find(params[:trial_entry][:trial_schedule_id])
    allow_overlap_dates = params[:allow_overlap_dates] == "true"
    entry = trial_schedule.trial_entries.build(entry_params)
    
    if !allow_overlap_dates && TrialEntry.check_overlap_dates(trial_schedule, entry)
      data = {failure:{msg: "Overlapping dates found for same visit.", overlapped: true}}
    else
      if entry.save
        data = {success:{msg: "Entry Added", name: entry.event_id, type: entry.type}}
      else
        key, val = entry.errors.messages.first
        data = {failure:{msg: entry.errors.full_messages.first, element_id: "trial_entry_#{key}"}}
      end
    end

    render json: data
  end

  # GET   /dashboard/trial/:trial_id/entries/:id/edit(.:format) 
  def edit
    @entry = TrialEntry.find(params[:id])
    @event_ids = event_ids(@entry.type)
    @categories = @trial.vpd.vpd_ledger_categories.order(name: :asc).map{|cat| [cat.name, cat.id.to_s]}
    @categories.unshift(["UNSPECIFIED", nil])

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/trial/:trial_id/entries/:id(.:format)  
  def update
    entry = TrialEntry.find(params[:id])
    allow_overlap_dates = params[:allow_overlap_dates] == "true"
    entry.assign_attributes(entry_params)
    if !allow_overlap_dates && TrialEntry.check_overlap_dates(entry.trial_schedule, entry)
      data = {failure:{msg: "Overlapping dates found for same visit.", overlapped: true}}
    else
      if entry.save
        data = {success:{msg: "Entry Updated", name: entry.event_id, type: entry.type}}
      else
        key, val = entry.errors.messages.first
        data = {failure:{msg: entry.errors.full_messages.first, element_id: "trial_entry_#{key}"}}
      end
    end

    render json: data
  end

  # DELETE  /dashboard/trial/:trial_id/entries/:id(.:format) 
  def destroy
    entry = TrialEntry.find(params[:id])
    if entry.destroy
      data = {success:{msg: "Entry Deleted", type: entry.type}}
    else
      key, val = entry.errors.messages.first
      data = {failure:{msg: entry.errors.full_messages.first, element_id: "trial_entry_#{key}"}}
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def event_ids(type)
    TrialEvent.where(trial: @trial, status: 1, type: type).order(order: :asc)
  end

  def entry_params
    start_date = params[:trial_entry][:start_date].present? ? DateTime.strptime(params[:trial_entry][:start_date], "%m/%d/%Y").to_date : TrialEntry::DATE[:forever_start]
    end_date   = params[:trial_entry][:end_date].present? ? DateTime.strptime(params[:trial_entry][:end_date], "%m/%d/%Y").to_date : TrialEntry::DATE[:forever_end]
    params[:trial_entry][:start_date]  = start_date
    params[:trial_entry][:end_date]    = end_date
    params[:trial_entry][:user_id]     = current_user.id
    params[:trial_entry][:vpd_id]      = @trial.vpd.id

    params.require(:trial_entry).permit(:event_id, :type, :amount, :start_date, :end_date, :tax_rate, :holdback_rate, :advance, :event_cap, 
                                        :user_id, :vpd_ledger_category_id, :trial_schedule_id).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:trial_entry][:vpd_id]
    end
  end
end
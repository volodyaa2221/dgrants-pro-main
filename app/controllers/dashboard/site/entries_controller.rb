class Dashboard::Site::EntriesController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create, :edit, :update]
  before_action :authenticate_site_editable_user,         except: :index
  before_action :authenticate_site_level_user,            only: :index

  # Site Transaction Entry actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/entries(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SiteEntryDatatable.new(view_context, current_user, @site, params[:entry_type].to_i) }
    end
  end

  # GET   /dashboard/site/:site_id/entries/new(.:format)?transaction_type=0/1
  def new
    @type = params[:entry_type].to_i
    @tax_rate = @site.site_schedule.present? ? @site.site_schedule.tax_rate : 0
    @holdback_rate = @site.site_schedule.present? ? @site.site_schedule.holdback_rate : 0
    @event_ids = event_ids(@type)
    @categories = @site.vpd.vpd_ledger_categories.order(name: :asc).map{|cat| [cat.name, cat.id.to_s]}
    @categories.unshift(["UNSPECIFIED", nil])
    @entry = SiteEntry.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/entries(.:format)
  def create
    allow_overlap_dates = params[:allow_overlap_dates] == "true"
    @entry_params       = entry_params

    entry = @site.site_entries.build(@entry_params)
    if !allow_overlap_dates && SiteEntry.check_overlap_dates(@site, entry)
      data = {failure:{msg: "Overlapping dates found for same visit.", overlapped: true}}
    else
      trial_event = check_trial_event_exist(@entry_params[:event_id], @entry_params[:type])
      if trial_event == true
        if entry.save
          data = {success:{msg: "Entry Added", name: entry.event_id, type: entry.type}}
        else
          key, val = entry.errors.messages.first
          data = {failure:{msg: entry.errors.full_messages.first, element_id: "site_entry_#{key}"}}
        end
      else
        data = {failure:{msg: trial_event.errors.full_messages.first, element_id: "site_entry_event_id"}}
      end
    end

    render json: data
  end

  # GET   /dashboard/site/:site_id/entries/:id/edit(.:format)
  def edit
    @entry = SiteEntry.find(params[:id])
    @event_ids = event_ids(@entry.type)
    @categories = @site.vpd.vpd_ledger_categories.order(name: :asc).map{|cat| [cat.name, cat.id.to_s]}
    @categories.unshift(["UNSPECIFIED", nil])

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/site/:site_id/entries/:id(.:format)
  def update
    allow_overlap_dates = params[:allow_overlap_dates] == "true"
    @entry_params       = entry_params

    entry = SiteEntry.find(params[:id])
    entry.assign_attributes(@entry_params)
    if !allow_overlap_dates && SiteEntry.check_overlap_dates(@site, entry)
      data = {failure:{msg: "Overlapping dates found for same visit.", overlapped: true}}
    else
      trial_event = check_trial_event_exist(@entry_params[:event_id], @entry_params[:type])
      if trial_event == true
        if entry.save
          data = {success:{msg: "Entry Updated", name: entry.event_id, type: entry.type}}
        else
          key, val = entry.errors.messages.first
          data = {failure:{msg: entry.errors.full_messages.first, element_id: "site_entry_#{key}"}}
        end
      else
        data = {failure:{msg: trial_event.errors.full_messages.first, element_id: "site_entry_event_id"}}
      end
    end

    render json: data
  end

  # DELETE  /dashboard/site/:site_id/entries/:id(.:format)
  def destroy
    entry = SiteEntry.find(params[:id])
    if to_b(params[:delete])
      if entry.destroy
        data = {success:{msg: "Entry Deleted", type: entry.type}}
      else
        key, val = entry.errors.messages.first
        data = {failure:{msg: entry.errors.full_messages.first, element_id: "site_entry_#{key}"}}
      end
    else
      if entry.update_attributes(status: SiteEntry::STATUS[:disabled])
        entry.disable_transactions
        data = {success:{msg: "Entry Disabled", type: entry.type}}
      else
        key, val = entry.errors.messages.first
        data = {failure:{msg: entry.errors.full_messages.first, element_id: "site_entry_#{key}"}}
      end
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  def event_ids(type)
    TrialEvent.where(trial_id: @site.trial_id, status: 1, type: type).order(order: :asc)
  end

  def check_trial_event_exist(event_id, type)
    unless TrialEvent.where(event_id: event_id, type: type).first.present?
      max_order = TrialEvent.max_order_in_fields(@site.trial, type)
      if max_order.present?
        max_order += 1
      else
        max_order = 0
      end
      trial_event = @site.trial.trial_events.build(event_id: event_id, type: type, order: max_order)
      if trial_event.save
        true
      else
        trial_event
      end
    end
    true
  end

  def entry_params
    start_date = params[:site_entry][:start_date].present? ? DateTime.strptime(params[:site_entry][:start_date], "%m/%d/%Y").to_date : TrialEntry::DATE[:forever_start]
    end_date   = params[:site_entry][:end_date].present? ? DateTime.strptime(params[:site_entry][:end_date], "%m/%d/%Y").to_date : TrialEntry::DATE[:forever_end]
    params[:site_entry][:start_date]  = start_date
    params[:site_entry][:end_date]    = end_date
    params[:site_entry][:user_id]     = current_user.id.to_s
    params[:site_entry][:vpd_id]      = @site.vpd.id
    params.require(:site_entry).permit(:event_id, :type, :amount, :start_date, :end_date, :tax_rate, :holdback_rate, :advance, :event_cap,
                                      :user_id, :vpd_ledger_category_id).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:site_entry][:vpd_id]
    end
  end
end

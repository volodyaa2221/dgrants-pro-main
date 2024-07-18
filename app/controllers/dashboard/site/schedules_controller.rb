class Dashboard::Site::SchedulesController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: :save_schedule
  before_action :authenticate_site_editable_user,         except: [:index, :schedule]
  before_action :authenticate_site_level_user,            only: :edit

  # Site Payment Schedule actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/schedule(.:format)  
  def schedule
    @schedule = @site.site_schedule
    @vpd_currency = @schedule.vpd_currency
    @schedule_activated = @schedule.ever_activated?

    @trial_schedules = TrialSchedule.where(trial: @site.trial, vpd_currency: @vpd_currency, status: 1).map do |ts|
      [ts.name, ts.id]
    end
    @trial_schedules.unshift(["No Template", nil])
    @symbol = @vpd_currency.present? ? @vpd_currency.symbol : ''

    render layout: params[:type] != "ajax"
  end

  # POST   /dashboard/site/:site_id/save_schedule(.:format)
  def save_schedule
    refresh    = params.include?(:mode)
    schedule   = @site.site_schedule
    ts_changed = !refresh && (schedule.trial_schedule.present? && 
                  schedule.trial_schedule_id != params[:trial_schedule_id].to_i)
    schedule   = @site.build_site_schedule(vpd: @site.vpd) unless schedule.present?

    if schedule.update_attributes(schedule_params)
      if ts_changed
        SitePassthroughBudget.where(site: @site).destroy_all
        SiteEntry.where(site: @site).destroy_all
        trial_schedule = schedule.trial_schedule
        if trial_schedule.present?
          schedule.update_attributes(tax_rate: trial_schedule.tax_rate, withholding_rate: trial_schedule.withholding_rate, overhead_rate: trial_schedule.overhead_rate,
                        holdback_rate: trial_schedule.holdback_rate, holdback_amount: trial_schedule.holdback_amount, payment_terms: trial_schedule.payment_terms)

          TrialEntry.where(trial_schedule: trial_schedule).each do |entry|
            @site.site_entries.create(event_id: entry.event_id, type: entry.type, amount: entry.amount, tax_rate: entry.tax_rate, holdback_rate: entry.holdback_rate, 
                                    advance: entry.advance, event_cap: entry.event_cap, start_date: entry.start_date, end_date: entry.end_date, 
                                    user: entry.user, vpd: @site.vpd, vpd_ledger_category: entry.vpd_ledger_category)
          end
          TrialPassthroughBudget.where(trial_schedule: trial_schedule).each do |budget|
            @site.site_passthrough_budgets.create(name: budget.name, max_amount: budget.max_amount, monthly_amount: budget.monthly_amount, vpd: @site.vpd)
          end
        else
          schedule.update_attributes(tax_rate: 0, withholding_rate: 0, overhead_rate: 0, holdback_rate: 0, holdback_amount: 0, payment_terms: 30)
        end
      end

      if refresh
        ever_activated = schedule.ever_activated?
        data = {success:{msg: "Budget Updated", text: "Budget has been saved successfully.", refresh: refresh, ts_changed: ts_changed, ever_activated: ever_activated}}
      else
        data = {success:{msg: "Budget Updated", text: "Budget has been saved successfully.", refresh: refresh, ts_changed: ts_changed}}
      end
    else
      key, val = site_event.errors.messages.first
      data = {failure:{msg: site_event.errors.full_messages.first, element_id: key}}
    end

    render json: data
  end

  # GET   /dashboard/site/:site_id/new_authenticate(.:format) 
  def new_authenticate
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/authenticate(.:format)  
  def authenticate
    user = User.where("email = '#{params[:email]}' AND id != #{current_user.id}")
    if user.exists?
      if user.first.valid_password?(params[:password])
        if @site.trial.trial_admin?(user.first)
          schedule = @site.site_schedule
          if schedule.present?
            schedule.update_attributes(mode: false)
          else
            schedule = @site.build_site_schedule(mode: false)
            schedule.save
          end
          data = {success:{msg: "Budget Updated", text: "Budget has been changed to payable mode successfully."}}
        else
          data = {failure:{msg: "This user isn't TA of this trial", element_id: "email"}}
        end
      else
        data = {failure:{msg: "Password is incorrect", element_id: "password"}}
      end
    else
      data = {failure:{msg: "Email is incorrect", element_id: "email"}}
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def schedule_params
    params.permit(:mode, :trial_schedule_id, :tax_rate, :withholding_rate, :overhead_rate, :holdback_rate, :holdback_amount, :payment_terms)
  end
end
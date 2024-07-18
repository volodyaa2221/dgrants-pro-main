class Dashboard::Trial::SchedulesController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Template Schedule actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/schedules(.:format)  
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: TrialScheduleDatatable.new(view_context, current_user, @trial) }
    end
  end

  # GET   /dashboard/trial/:trial_id/schedules/new(.:format) 
  def new
    @currencies = @trial.vpd_currencies(false).order(code: :asc).map do |vpd_currency|
      [vpd_currency.code, vpd_currency.id.to_s]
    end
    @schedule = TrialSchedule.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/trial/:trial_id/schedules(.:format) 
  def create
    schedule = @trial.trial_schedules.build(schedule_params)
    if schedule.save
      data = {success:{msg: "Budget Template Added", name: schedule.name}}
    else
      key, val = schedule.errors.messages.first
      data = {failure:{msg: schedule.errors.full_messages.first, element_id: "trial_schedule_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/trial/:trial_id/schedules/:id/edit(.:format) 
  def edit
    @schedule = TrialSchedule.find(params[:id])
    @vpd_currency = @schedule.vpd_currency
    @symbol = @vpd_currency.present? ? @vpd_currency.symbol : ''

    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.js
    end
  end

  # PUT|PATCH   /dashboard/trial/:trial_id/schedules/:id(.:format) 
  def update
    schedule = TrialSchedule.find(params[:id])
    if schedule.update_attributes(schedule_params)
      data = {success:{msg: "Budget Template Updated", text: "Budget Template has been updated successfully", name: schedule.name}}
    else
      key, val = schedule.errors.messages.first
      data = {failure:{msg: schedule.errors.full_messages.first, element_id: "trial_schedule_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/trial/:trial_id/schedules/schedules_by_currency(.:format)
  def schedules_by_currency
    @trial_schedules = TrialSchedule.where(trial: @trial, vpd_currency_id: params[:vpd_currency_id]).order(name: :asc).map do |schedule|
      [schedule.name, schedule.id.to_s]
    end
    @trial_schedules.unshift(["No Template", "0"])

    render layout: false
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def schedule_params
    if params[:trial_schedule][:vpd_currency].present?
      vpd_currency = VpdCurrency.find(params[:trial_schedule][:vpd_currency])
      params[:trial_schedule][:currency_id] = vpd_currency.currency_id
      params[:trial_schedule][:vpd_currency_id] = vpd_currency.id
    end
    params[:trial_schedule][:vpd_id] = @trial.vpd.id
    params.require(:trial_schedule).permit(:name, :tax_rate, :withholding_rate, :overhead_rate, :holdback_rate, :holdback_amount, :payment_terms, 
                                          :currency_id, :vpd_currency_id).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:trial_schedule][:vpd_id]
    end
  end
end
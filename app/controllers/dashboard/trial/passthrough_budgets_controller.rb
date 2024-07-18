class Dashboard::Trial::PassthroughBudgetsController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Passthrough Budget Entry actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/passthrough_budgets?schedule={schedule_id}(.:format) 
  def index
    schedule = TrialSchedule.find(params[:schedule])
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: TrialPassthroughBudgetDatatable.new(view_context, current_user, @trial, schedule) }
    end
  end

  # GET   /dashboard/trial/:trial_id/passthrough_budgets/new?schedule={schedule_id}(.:format)
  def new
    @schedule = TrialSchedule.find(params[:schedule])
    @budget   = TrialPassthroughBudget.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/trial/:trial_id/passthrough_budgets(.:format) 
  def create
    trial_schedule = TrialSchedule.find(params[:trial_passthrough_budget][:trial_schedule_id])
    budget = trial_schedule.trial_passthrough_budgets.build(passthrough_budget_params)
    if budget.save
      data = {success:{msg: "Passthrough Budget Entry Added", name: budget.name}}
    else
      key, val = budget.errors.messages.first
      data = {failure:{msg: budget.errors.full_messages.first, element_id: "trial_passthrough_budget_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/trial/:trial_id/passthrough_budgets/:id/edit(.:format) 
  def edit
    @budget = TrialPassthroughBudget.find(params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/trial/:trial_id/passthrough_budgets/:id(.:format) 
  def update
    budget = TrialPassthroughBudget.find(params[:id])
    if budget.update_attributes(passthrough_budget_params)
      data = {success:{msg: "Entry Updated", name: budget.name}}
    else
      key, val = budget.errors.messages.first
      data = {failure:{msg: budget.errors.full_messages.first, element_id: "trial_passthrough_budget_#{key}"}}
    end

    render json: data
  end

  # DELETE  /dashboard/trial/:trial_id/passthrough_budgets/:id(.:format) 
  def destroy
    budget = TrialPassthroughBudget.find(params[:id])
    if budget.destroy
      data = {success:{msg: "Entry Deleted", name: budget.name}}
    else
      key, val = budget.errors.messages.first
      data = {failure:{msg: budget.errors.full_messages.first, element_id: "trial_passthrough_budget_#{key}"}}
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  
  def passthrough_budget_params
    params[:trial_passthrough_budget][:max_amount] = 0 if !params[:trial_passthrough_budget][:max_amount].present?
    params[:trial_passthrough_budget][:monthly_amount] = 0 if !params[:trial_passthrough_budget][:monthly_amount].present?
    params[:trial_passthrough_budget][:vpd_id] = @trial.vpd.id
    params.require(:trial_passthrough_budget).permit(:name, :max_amount, :monthly_amount, :vpd_id)
  end
end
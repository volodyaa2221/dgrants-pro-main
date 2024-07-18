class Dashboard::Site::PassthroughBudgetsController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create, :edit, :update]
  before_action :authenticate_site_editable_user,         except: :index
  before_action :authenticate_site_level_user,            only: :index

  # Site Passthrough Budget Entry actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/passthrough_budgets(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SitePassthroughBudgetDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/passthrough_budgets/new(.:format)  
  def new
    @budget = SitePassthroughBudget.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/passthrough_budgets(.:format) 
  def create
    budget = @site.site_passthrough_budgets.build(passthrough_budget_params)
    if budget.save
      data = {success:{msg: "Passthrough Budget Entry Added", name: budget.name}}
    else
      key, val = budget.errors.messages.first
      data = {failure:{msg: budget.errors.full_messages.first, element_id: "site_passthrough_budget_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/site/:site_id/passthrough_budgets/:id/edit(.:format) 
  def edit
    @budget = SitePassthroughBudget.find(params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/site/:site_id/passthrough_budgets/:id(.:format) 
  def update
    budget = SitePassthroughBudget.find(params[:id])
    if budget.update_attributes(passthrough_budget_params)
      data = {success:{msg: "Entry Updated", name: budget.name}}
    else
      key, val = budget.errors.messages.first
      data = {failure:{msg: budget.errors.full_messages.first, element_id: "site_passthrough_budget_#{key}"}}
    end

    render json: data
  end

  # DELETE  /dashboard/site/:site_id/passthrough_budgets/:id(.:format) 
  def destroy
    budget = SitePassthroughBudget.find(params[:id])
    if to_b(params[:delete])
      if budget.destroy
        data = {success:{msg: "Entry Deleted", name: budget.name}}
      else
        key, val = budget.errors.messages.first
        data = {failure:{msg: budget.errors.full_messages.first, element_id: "site_passthrough_budget_#{key}"}}
      end
    else 
      if budget.update_attributes(status: 0)
        budget.disable_transactions
        data = {success:{msg: "Entry Disabled", name: budget.name}}
      else
        key, val = budget.errors.messages.first
        data = {failure:{msg: budget.errors.full_messages.first, element_id: "site_passthrough_budget_#{key}"}}
      end      
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def passthrough_budget_params
    params[:site_passthrough_budget][:max_amount] = 0     if !params[:site_passthrough_budget][:max_amount].present?
    params[:site_passthrough_budget][:monthly_amount] = 0 if !params[:site_passthrough_budget][:monthly_amount].present?    
    params[:site_passthrough_budget][:vpd_id] = @site.vpd.id
    params.require(:site_passthrough_budget).permit(:name, :max_amount, :monthly_amount).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:site_passthrough_budget][:vpd_id]
    end
  end
end
class Dashboard::Vpd::LedgerCategoriesController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Ledger Categories actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/ledger_categories(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: LedgerCategoryDatatable.new(view_context, current_user, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/ledger_categories/new(.:format) 
  def new
    @category = VpdLedgerCategory.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/ledger_categories(.:format) 
  def create
    category = @vpd.vpd_ledger_categories.build(category_params)
    if category.save
      data = {success:{msg: "Category Added", name: category.name}}
    else
      key, val = category.errors.messages.first
      data = {failure:{msg: category.errors.full_messages.first, element_id: "vpd_ledger_category_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/vpd/:vpd_id/ledger_categories/:id/edit(.:format) 
  def edit
    @category = VpdLedgerCategory.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/vpd/:vpd_id/ledger_categories/:id(.:format) 
  def update
    ledger_category = VpdLedgerCategory.find(params[:id])
    if ledger_category.update_attributes(category_params)
      data = {success:{msg: "Ledger Category Updated", name: ledger_category.name}}
    else
      key, val = ledger_category.errors.messages.first
      data = {failure:{msg: ledger_category.errors.full_messages.first, element_id: "vpd_ledger_category_#{key}"}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def category_params
    params.require(:vpd_ledger_category).permit(:name)
  end
end
class Dashboard::Site::PassthroughsController < DashboardController
  include Dashboard::SiteHelper
  include Dashboard::DocumentFileHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create, :edit, :update]
  before_action :authenticate_site_editable_user,         except: :index
  before_action :authenticate_site_level_user,            only: :index

  # Site Passthrough actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/passthroughs(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: PassthroughDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/passthroughs/new(.:format)  
  def new
    @passthrough = Passthrough.new
    @passthrough_budgets = passthrough_budgets

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/:site_id/passthroughs(.:format) 
  def create
    # @result = nil
    # passthrough = @site.passthroughs.build(passthrough_params)
    # if passthrough.save
    #   @result = {success: true, msg: "Passthrough Invoice Added", name: passthrough.budget_name}
    # else
    #   key, val = passthrough.errors.messages.first
    #   @result = {success: false, msg: passthrough.errors.full_messages.first, element_id: "passthrough_#{key}"}
    # end
    invoice_file = InvoiceFile.create(file: params[:invoice_file])
    @result = nil
    if invoice_file.errors.count == 0
      passthrough = @site.passthroughs.build(passthrough_params)
      if passthrough.save
        invoice_file.update_attributes(passthrough: passthrough)
        @result = {success: true, msg: "Passthrough Invoice Added", name: passthrough.budget_name}
      else
        key, val = passthrough.errors.messages.first
        @result = {success: false, msg: passthrough.errors.full_messages.first, element_id: "passthrough_#{key}"}
      end
    else
      key, val = invoice_file.errors.messages.first
      @result = {success: false, msg: invoice_file.errors.full_messages.first, element_id: "invoice_file"}
    end

    respond_to do |format|
      format.js
    end
  end

  # GET   /dashboard/site/:site_id/passthroughs/:id/edit(.:format) 
  def edit
    @passthrough = Passthrough.find(params[:id])
    @status = [["Approved", 2], ["Disabled", 0]]
    invoice_file = @passthrough.invoice_file
    @invoice_file_name = nil
    if invoice_file.present?
      @invoice_file_name = invoice_file.name
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/site/:site_id/passthroughs/:id(.:format) 
  def update
    passthrough = Passthrough.find(params[:id])
    prev_status = passthrough.status
    if passthrough.update_attributes(status: params[:passthrough][:status])
      if params[:passthrough][:status].to_i == Passthrough::STATUS[:disabled]
        passthrough.disable_transactions 
      elsif prev_status == Passthrough::STATUS[:pending]  &&  params[:passthrough][:status].to_i == Passthrough::STATUS[:approved]
        passthrough.create_transactions
      end
      data = {success:{msg: "Passthrough Updated", name: passthrough.budget_name}}
    else
      key, val = passthrough.errors.messages.first
      data = {failure:{msg: passthrough.errors.full_messages.first, element_id: "passthrough_#{key}"}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def passthrough_budgets
    SitePassthroughBudget.where(site: @site, status: SitePassthroughBudget::STATUS[:payable]).order(name: :asc).map do |budget|
      [budget.name, budget.id.to_s]
    end    
  end

  def passthrough_params
    budget = SitePassthroughBudget.find(params[:passthrough][:site_passthrough_budget])
    params[:passthrough][:budget_name] = budget.name
    params[:passthrough][:site_passthrough_budget_id] = budget.id
    params[:passthrough][:happened_at] = Time.now.to_date
    params[:passthrough][:vpd_id]      = @site.vpd.id
    params.require(:passthrough).permit(:description, :budget_name, :amount, :happened_at, :site_passthrough_budget_id, :vpd_id)
  end
end
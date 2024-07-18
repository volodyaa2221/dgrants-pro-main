class Dashboard::CurrenciesController < DashboardController
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin

  # Currency actions
  #----------------------------------------------------------------------
  # GET   /dashboard/currencies(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: CurrencyDatatable.new(view_context, current_user) }
    end
  end

  # GET /dashboard/currencies/new
  def new
    @currency = Currency.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/currencies(.:format)
  def create
    currency = Currency.new(currency_params)
    if currency.save
      data = {success:{msg: "Currency Added", name: currency.code}}
    else
      key, val = currency.errors.messages.first
      data = {failure:{msg: currency.errors.full_messages.first, element_id: "currency_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/currencies/:id/edit(.:format)
  def edit
    @currency = Currency.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/currencies/:id(.:format) 
  def update
    currency = Currency.find(params[:id])
    if currency.update_attributes(currency_params)
      data = {success:{msg: "Currency Updated", name: currency.code}}
    else
      key, val = currency.errors.messages.first
      data = {failure:{msg: currency.errors.full_messages.first, element_id: "currency_#{key}"}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def currency_params
    params.require(:currency).permit(:code, :description, :symbol, :rate)
  end
end
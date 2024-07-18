class Dashboard::Vpd::CurrenciesController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD Currency actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/currencies(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: CurrencyDatatable.new(view_context, current_user, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/currencies/new(.:format)
  def new
    @currency = VpdCurrency.new
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/vpd/:vpd_id/currencies(.:format)
  def create
    currency = Currency.where(code: params[:vpd_currency][:code])
    if currency.exists?
      currency     = currency.first
      vpd_currency = @vpd.vpd_currencies.build(currency: currency)
    else
      currency = Currency.new(code: params[:vpd_currency][:code], status: 0)
      if currency.save
        vpd_currency = @vpd.vpd_currencies.build(currency: currency)
      else
        key, val = currency.errors.messages.first
        data = {failure:{msg: currency.errors.full_messages.first, element_id: "vpd_currency_code"}}
      end
    end

    if data.nil?
      if vpd_currency.save
        data = {success:{msg: "Currency Added", name: vpd_currency.code}}
      else
        key, val = vpd_currency.errors.messages.first
        data = {failure:{msg: vpd_currency.errors.full_messages.first, element_id: "vpd_currency_code"}}
      end
    end

    render json: data
  end

  # POST  /dashboard/vpd/:vpd_id/currencies/:currency_id/update_status(.:format) 
  def update_status
    model   = params[:object].constantize
    object  = model.find(params[:status_id])
    status  = params[:status]

    if model.name == Currency.name
      vpd_currency = @vpd.vpd_currencies.build(currency: object, status: status)
    else
      vpd_currency = object
      vpd_currency.assign_attributes(status: status)
    end

    if vpd_currency.present? && vpd_currency.save
      render json: {success:{msg: "Updated #{params[:object]}", id: object.id.to_s}}
    else
      render json: {failure:{msg: vpd_currency.errors.full_messages.first}}
    end
  end
end
class Dashboard::Site::PaymentInfosController < DashboardController
  include Dashboard::SiteHelper
  include Dashboard::Site::PaymentInfosHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_editable_user,         except: :edit_payment_info
  before_action :authenticate_site_level_user,            only: :edit_payment_info

  # Site Payment Info actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/payment_infos/edit_payment_info(.:format)
  def edit_payment_info
    if @site.payment_info.present?
      @payment_info = @site.payment_info
      @form_url = dashboard_site_payment_info_path(@site, @site.payment_info)
    else
      @payment_info = PaymentInfo.new
      @form_url = dashboard_site_payment_infos_path(@site)
    end
    
    collect_PIF_data

    render layout: params[:type] != "ajax"
  end

  # POST  /dashboard/site/:site_id/payment_infos(.:format)
  def create
    @payment_info = @site.build_payment_info(payment_info_params)
    if @payment_info.save
      update_site
      data = {success:{msg: "Banking Details Added"}}
    else
      key, val = @payment_info.errors.messages.first
      data = {failure:{msg: @payment_info.errors.full_messages.first, element_id: "payment_info_#{key}"}}
    end

    render json: data
  end

  # PUB|PATCH   /dashboard/site/:site_id/payment_infos/:id(.:format)
  def update
    @payment_info = PaymentInfo.find(params[:id])
    if @payment_info.update_attributes(payment_info_params)
      update_site
      data = {success:{msg: "Banking Details Updated."}}
    else
      key, val = @payment_info.errors.full_messages.first
      data = {failure:{msg: @payment_info.errors.full_messages.first, element_id: "payment_info_#{key}"}}
    end

    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def payment_info_params
    params[:payment_info][:site_id] = @site.id
    params.require(:payment_info).permit(:country, :currency_code, 
                                         :field1_label, :field1_value, :field2_label, :field2_value, :field3_label, :field3_value, 
                                         :field4_label, :field4_value, :field5_label, :field5_value, :field6_label, :field6_value, 
                                         :bank_name, :bank_street_address, :bank_city, :bank_state,:bank_postcode, :site_id)
  end

  # Private: Checks country of site exists in PIF table and collects it
  def collect_PIF_data
    @currency_codes = []
    @country_info   = ""
    if @site.country_name.present?
      @payment_info.country = @site.country_name
      pif_data  = country_payment_info(@site.country_name)
      if pif_data.present?
        @currency_codes = pif_data[:currency_codes]
        @payment_info.field1_label = pif_data[:field1_label]
        @payment_info.field2_label = pif_data[:field2_label]
        @payment_info.field3_label = pif_data[:field3_label]
        @payment_info.field4_label = pif_data[:field4_label]
        @payment_info.field5_label = pif_data[:field5_label]
        @payment_info.field6_label = pif_data[:field6_label]
      else
        @country_info = "Automated payments to #{@site.country_name} are not currently available."
      end
    else
      @country_info = "There is no country selected for the current site."
    end
  end

  # Private: Updates payment verified status of site after saving payment info
  def update_site
    if @payment_info.missing_some_fields?
      @site.update_attributes(payment_verified: Site::PAYMENT_VERIFIED[:known_bad])
    else
      @site.update_attributes(payment_verified: Site::PAYMENT_VERIFIED[:presumed_good])
    end
  end

end
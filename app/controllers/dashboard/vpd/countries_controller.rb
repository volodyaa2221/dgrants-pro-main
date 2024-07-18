class Dashboard::Vpd::CountriesController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd, except: :provinces
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user, except: :provinces

  # VPD Country actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/countries(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: CountryDatatable.new(view_context, current_user, @vpd) }
    end    
  end

  # POST  /dashboard/vpd/:vpd_id/countries/:country_id/update_status(.:format) 
  def update_status
    model   = params[:object].constantize
    object  = model.find(params[:status_id])
    status  = params[:status]

    if model.name == Country.name
      vpd_country = @vpd.vpd_countries.build(country: object, status: status)
    else
      vpd_country = object
      vpd_country.assign_attributes(status: status)
    end

    if vpd_country.present? && vpd_country.save
      render json: {success:{msg: "Updated #{params[:object]}", id: object.id.to_s}}
    else
      render json: {failure:{msg: vpd_country.errors.full_messages.first}}
    end
  end


  # Utility actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/countries/provinces(.:format)
  def provinces
    @vpd_country = VpdCountry.find(params[:country_id])
    render layout: false    
  end
end
class Dashboard::CountriesController < DashboardController
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin

  # GET   /dashboard/countries(.:format)
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: CountryDatatable.new(view_context, current_user) }
    end    
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  def country_params
    code = params[:country][:name]
    name = Carmen::Country.coded(code).name
    params[:country][:code] = code
    params[:country][:name] = name
    params.require(:country).permit(:code, :name)    
  end
end
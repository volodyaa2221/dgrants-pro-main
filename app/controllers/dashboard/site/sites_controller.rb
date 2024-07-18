class Dashboard::Site::SitesController < DashboardController
  include Dashboard::SiteHelper

  skip_before_action :authenticate_super_admin

  before_action :get_trial, only: [:new, :create]
  before_action :get_site, except: [:new, :create]

  before_action :authenticate_verify_user
  before_action :authenticate_site_creatable_user, only: [:new, :create]
  before_action :authenticate_site_details_editable_user, only: :update
  before_action :authenticate_site_level_user, only: [:edit, :dashboard]

  # Site actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/sites/new(.:format) 
  def new
    @currencies = @trial.vpd_currencies(false).order(code: :asc).map do |vpd_currency|
      [vpd_currency.code, vpd_currency.id.to_s]
    end
    @schedule_sites = [["No Template", "0"]]
    @site = Site.new

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST  /dashboard/site/sites(.:format) 
  def create
    site = @trial.sites.build(site_params)
    if site.save
      vpd_currency = VpdCurrency.find(params[:vpd_currency])
      currency_id = vpd_currency.currency_id
      if params[:schedule_site].present? && params[:schedule_site] != "0"
        schedule_site = Site.where(id: params[:schedule_site]).first
        if schedule_site.present?
          site_schedule = schedule_site.try(:site_schedule)
          schedule = site.create_site_schedule(tax_rate: site_schedule.tax_rate, withholding_rate: site_schedule.withholding_rate, overhead_rate: site_schedule.overhead_rate,
                                              holdback_rate: site_schedule.holdback_rate, holdback_amount: site_schedule.holdback_amount, payment_terms: site_schedule.payment_terms, 
                                              currency_id: currency_id, vpd: @trial.vpd, vpd_currency_id: params[:vpd_currency], trial_schedule_id: params[:trial_schedule])
          schedule.copy_entries_from_site(schedule_site)
        end
      else
        schedule = site.create_site_schedule(currency_id: currency_id, vpd: @trial.vpd, vpd_currency_id: params[:vpd_currency])
      end
      data = {success:{msg: "Site Added", name: site.site_id}}
      set_main_sub_site(site)
    else
      key, val = site.errors.messages.first
      data = {failure:{msg: site.errors.full_messages.first, element_id: "site_#{key}"}}
    end

    render json: data
  end

  # GET   /dashboard/site/sites/:id/edit(.:format) 
  def edit
    @countries = []
    VpdCountry.where(vpd: @site.vpd, status: 1).order(name: :asc).each do |vpd_country|
      @countries << [vpd_country.name, vpd_country.id.to_s]
    end

    vpd_country = @site.vpd_country
    if vpd_country.present?  &&  vpd_country.status == 0
      @countries << [vpd_country.name, vpd_country.id.to_s]
      @countries = @countries.uniq
    end

    @us_site = vpd_country.code.casecmp("us").zero?
    @states = [['', nil]]
    if @site.country.present?  &&  @site.country_name != "UNDEFINED"
      country = Carmen::Country.coded(@site.country.code)
      if country.present? && country.subregions?
        @states = []
        Carmen::Country.coded(country.code).subregions.each do |subregion|
          @states << [subregion.name, subregion.code]
        end
      else
        @states = [["Hong Kong", "HK"]] if country.name == "Hong Kong"
      end
    end

    @budget_template_name = @site.try(:site_schedule).try(:trial_schedule).try(:name)
    
    render layout: params[:type] != "ajax"
  end

  # PUT|PATCH   /dashboard/site/sites/:id(.:format) 
  def update
    if @site.update_attributes(site_params)
      render json: {success:{msg: "Site Updated", text: "Your changes have been updated successfully.", name: @site.site_id}}
      set_main_sub_site(@site)
    else
      key, val = @site.errors.messages.first
      render json: {failure:{msg: @site.errors.full_messages.first, element_id: "site_#{key}"}}
    end
  end

  # GET   /dashboard/site/sites/:id/dashboard(.:format) 
  def dashboard
    user = current_user
    if current_user.site_level_user?(@site) && !@site.vpd.site_dashboard.blank?
      @dashboard_url = "#{@site.vpd.site_dashboard}&sid=#{@site.id.to_s}"
      render layout: params[:type] != "ajax"
    else
      redirect_to dashboard_site_statement_path(@site)
    end
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def get_trial
    if params[:trial_id].present?
      @trial = Trial.find(params[:trial_id].to_i)
    else
      @trial = @site.trial if @site.present?
    end
  end

  def site_params
    if params[:site][:country].present?
      vpd_country = VpdCountry.find(params[:site][:country])
      country = vpd_country.country
      country_name = country.name
      state = Carmen::Country.coded(country.code).subregions.count==0 ? nil : Carmen::Country.coded(country.code).subregions.coded(params[:site][:state_code]).name
      state = country_name if country_name == "Hong Kong"

      params[:site][:vpd_country_id] = vpd_country.id.to_s
      params[:site][:country_id] = country.id.to_s
      params[:site][:country_name] = country_name
      params[:site][:state] = state
    end

    if @site.present? # for Updating
      params.require(:site).permit(:site_id, :name, :country_name, :state_code, :state, :city, :address, :zip_code, :site_type, :status, :pi_first_name, 
                                  :pi_last_name, :pi_dea, :drugdev_dea, :vpd_country_id, :country_id)
    else              # for Creating
      params[:site][:vpd_id] = @trial.vpd.id
      params.require(:site).permit(:site_id, :name, :country_name, :vpd_country_id, :state_code, :state, :city, :country_id, :vpd_currency).tap do |whitelisted|
        whitelisted[:vpd_id] = params[:site][:vpd_id]
      end
    end
  end

  def set_main_sub_site(site) # Set main site and sub sites
    if site.site_id.include?(".") # Sub Site
      mainSiteId = site.site_id.split(".")
      mainSiteId.pop if mainSiteId.count > 1
      mainSiteId = mainSiteId.join
      mainSite = Site.where("trial_id = #{@trial.id} AND site_id = #{mainSiteId}, id != #{site.id}")
      if mainSite.exists?
        site.update_attributes(main_site: mainSite.first)
      end
    else # Main Site
      Site.where("trial_id = :trial AND site_id LIKE :site_id AND id != :site_db_id", trial: @trial, site_id: /^#{site.site_id}\.\d+$/i, site_db_id: site.id).each do |subsite|
        subsite.update_attributes(main_site: site)
      end
    end
  end
end
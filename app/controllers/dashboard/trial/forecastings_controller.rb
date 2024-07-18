class Dashboard::Trial::ForecastingsController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial  
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, only: :save_forecastings
  before_action :authenticate_trial_level_user, except: :save_forecastings

  # Trial Forecasting actions
  # ----------------------------------------
  # GET   /dashboard/trial/:trial_id/forecastings(.:format) 
  def forecastings
    @vpd_countries  = @trial.vpd_countries
    @sites          = Site.where(trial: @trial, status: 1)
    @trial_events   = TrialEvent.where(trial: @trial, status: 1).order(type: :asc, dependency_id: :asc, days: :asc)
    start_date      = @trial.start_date
    end_date        = @trial.end_date
    months          = months(start_date, end_date)
    @from           = months.map do |month|
      [month[:month], month[:from].strftime("%m/%d/%Y")]
    end
    @to             = months.map do |month|
      [month[:month], month[:to].strftime("%m/%d/%Y")]
    end
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: ForecastingDatatable.new(view_context, current_user, @trial) }
    end
  end

  # POST|PUT|PATCH  /dashboard/trial/:trial_id/save_forecastings(.:format) 
  def save_forecastings
    count = params[:forecastings].count
    params[:forecastings].each do |key, val|
      temp = Forecasting.where(trial: @trial, vpd_country_id: val[:vpd_country_id])
      est_start_date    = val[:est_start_date].present? ? DateTime.strptime(val[:est_start_date], "%m/%d/%Y").to_date : nil
      recruitment_rate  = val[:recruitment_rate]
      if (est_start_date.nil? || est_start_date.blank?) && (recruitment_rate.nil? || recruitment_rate.blank?)
        count -= 1
      else
        if temp.exists?
          forecasting = temp.first
          count-=1 if forecasting.update_attributes(est_start_date: est_start_date, recruitment_rate: recruitment_rate)
        else
          forecasting = @trial.forecastings.build(vpd_country_id: val[:vpd_country_id], est_start_date: est_start_date, recruitment_rate: recruitment_rate, vpd: @trial.vpd)
          count-=1 if forecasting.save
        end
      end
    end

    if count == 0
      data = {success:{msg: "Forecasting Updated", name:"Forecasting"}}
    elsif count < params[:forecastings].count      
      data = {failure:{msg: "Forecasting Updating Failed"}, details: "Some Updating Forecasting has been failed"}
    else count == params[:forecastings].count
      data = {failure:{msg: "Forecasting Updating Failed"}, details: "Updating Forecasting has been failed"}
    end
    
    render json: data
  end

  # GET   /dashboard/trial/:trial_id/sites(.:format)
  def sites_for_country
    sites   = @trial.sites_for_vpd_country(params[:vpd_country])
    @sites  = sites.map{|site| [site.site_id, site.id.to_s]}
    @sites.unshift(["All Sites", "all_sites"])

    render layout: false    
  end

  # POST  /dashboard/trial/:trial_id/create_forecast(.:format) 
  def create_forecast
    if @trial.forecasting_now
      data = {failure:{msg: "Trial is forecasting now", forecasted: false}}
    else
      force_forecast = to_b(params[:force_forecast])
      if @trial.should_forecast || force_forecast
        @trial.forecast
        data = {success:{msg: "Forecast caluculations commenced. This may take up to 5 mins", forecasted: false}}
      else
        data = {failure:{msg: "Trial has been already forecasted.", forecasted: true}}
      end
    end
    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  # Private: Get month(MMM-yy) array
  def months(from, to)
    number_of_months = (to.year*12+to.month)-(from.year*12+from.month)
    @months = (number_of_months+1).times.each_with_object([]) do |count, array|
      date = from.beginning_of_month + count.months
      from_date = date.beginning_of_month
      to_date   = date.end_of_month

      array << {month: date.strftime("%b - %y"), from: from_date, to: to_date}
    end
  end
end
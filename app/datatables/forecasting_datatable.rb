class ForecastingDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, trial)
    @view   = view
    @user   = user
    @trial  = trial
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: forecastings.count,
      iTotalDisplayRecords: forecastings.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    index = 0
    forecastings.map do |forecasting|
      index += 1
      [
        forecasting[:country_name] + "<input type='hidden' class='forecasting_row' id='country_#{index}' name='country_#{index}' value='#{forecasting[:vpd_country_id]}' />",
        "<input type='text' class='form-control input-sm input_element date-picker' data-type='date' data-provide='datepicker' placeholder='e.g. 12/25/2014' id='est_start_date_#{forecasting[:vpd_country_id]}' value='#{forecasting[:est_start_date]}' data-parsley-pattern='^[0-9]{1,2}[/]{1}[0-9]{1,2}[/]{1}[0-9]{4}$' data-parsley-error-message='No valid date' />".html_safe,
        "<input type='text' class='form-control input-sm input_element' placeholder='e.g. 1' id='recruitment_rate_#{forecasting[:vpd_country_id]}' value='#{forecasting[:recruitment_rate]}' data-parsley-type='number' data-parsley-error-message='No valid number' />".html_safe,
        # forecasting[:real_recruitment_rate],
        "row_"+forecasting[:vpd_country_id]
      ]
    end
  end

  def forecastings
    @forecastings ||= fetch_forecastings
  end

  def fetch_forecastings
    vpd_countries = @trial.vpd_countries
    forecastings = vpd_countries.map do |vpd_country|
      forecasting = Forecasting.where(vpd_country: vpd_country, trial: @trial)
      est_start_date    = nil
      recruitment_rate  = nil
      if forecasting.exists?
        forecasting       = forecasting.first
        est_start_date    = forecasting.est_start_date.present? ? forecasting.est_start_date.strftime("%m/%d/%Y") : nil
        recruitment_rate  = forecasting.recruitment_rate
      end
      real_recruitment_rate = vpd_country.real_recruitment_rate(@trial)
      {vpd_country_id: vpd_country.id.to_s, country_name: vpd_country.name, est_start_date: est_start_date, recruitment_rate: recruitment_rate, 
      real_recruitment_rate: real_recruitment_rate.present? ? real_recruitment_rate.round(2) : nil} 
    end

    if sort_column == "country_name"
      forecastings = sort_direction=="asc" ? forecastings.sort_by{|e| e[:country_name]} : forecastings.sort{|r, u| u[:country_name].downcase <=> r[:country_name].downcase}
    elsif sort_column == "forecast_start"
      forecastings = sort_direction=="asc" ? forecastings.sort_by{|e| sort_by_element(e[:est_start_date], :date)} : forecastings.sort{|r, u| sort_element(u[:est_start_date], r[:est_start_date])}
    elsif sort_column == "recruitment"   
      forecastings = sort_direction=="asc" ? forecastings.sort_by{|e| sort_by_element(e[:recruitment_rate])} : forecastings.sort{|r, u| sort_element(u[:recruitment_rate], r[:recruitment_rate])}
    end

    forecastings = forecastings.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 50
  end

  def sort_column
    columns = %w[country_name forecast_start recruitment]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def sort_by_element(val, option=nil)
    if option.nil?
      val.present? ? val : 0
    elsif option == :date
      val.present? ? val : ''
    end
  end

  def sort_element(val1, val2)
    if val1.present? && val2.present?
      val1 <=> val2
    elsif val1.present? && val2.nil?
      1
    elsif val1.nil? && val2.present?
      -1
    elsif val1.nil? && val2.nil?
      0
    end
  end
end
class Dashboard::Trial::ReportController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial  
  before_action :authenticate_verify_user
  before_action :authenticate_trial_level_user

  # Trial Forecasting Report actions
  # ----------------------------------------
  # GET   /dashboard/trial/:trial_id/report(.:format) 
  def report
    from            = params[:from].present? ? DateTime.strptime(params[:from], "%m/%d/%Y").to_date : nil
    to              = params[:to].present? ? DateTime.strptime(params[:to], "%m/%d/%Y").to_date : nil
    event_id        = params[:event_id]
    option          = params[:option]
    site_id         = params[:site]
    vpd_country_id  = params[:vpd_country]

    number_of_months = (to.year*12+to.month)-(from.year*12+from.month)
    months = (number_of_months+1).times.each_with_object([]) do |count, array|
      date = from.beginning_of_month + count.months
      from_date = date.beginning_of_month
      to_date   = date.end_of_month
      array << {month: date.strftime("%b - %y"), from: from_date, to: to_date}
    end
    max_val         = nil
    real_events         = []
    forecasting_events  = []
    total_events        = []

    if site_id == "all_sites"
      sites = @trial.sites_for_vpd_country(vpd_country_id)
      site_ids = sites.map(&:id)
    else 
      site_id = Site.find(site_id).id 
    end

    months.each do |month|
      if site_id == "all_sites"
        if event_id != "USD"
          real_logs = forecasting_logs = 0
          if site_ids.present?
            where_case = "event_id = '#{event_id}' AND happened_at >= '#{month[:from]}' AND happened_at <= '#{month[:to]}' AND status = 1 AND site_id IN (#{site_ids.join(",")})"
            real_logs = SiteEvent.where("#{where_case} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").count
            forecasting_logs = SiteEvent.where("#{where_case} AND source = '#{SiteEvent::SOURCE[:forecasting]}'").count
          end
        else 
          real_logs = forecasting_logs = 0
          if site_ids.present?
            Transaction.where("created_at >= '#{month[:from]}' AND created_at <= '#{month[:to]}' AND site_id IN (#{site_ids.join(",")}) AND source != '#{SiteEvent::SOURCE[:forecasting]}'").each do |t|
              amount    = t.amount + t.tax
              real_logs += (amount + t.advance) * t.usd_rate
            end
            real_logs = real_logs.round
            Transaction.where("happened_at >= '#{month[:from]}' AND happened_at <= '#{month[:to]}' AND site_id IN (#{site_ids.join(",")}) AND source = '#{SiteEvent::SOURCE[:forecasting]}'").each do |t|
              amount            = t.amount + t.tax
              forecasting_logs += (amount + t.advance) * t.usd_rate
            end
            forecasting_logs = forecasting_logs.round
          end
        end
      else
        if event_id != "USD"
          where_case = "event_id = '#{event_id}' AND happened_at >= '#{month[:from]}' AND happened_at <= '#{month[:to]}' AND status = 1 AND site_id = '#{site_id}'"
          real_logs = SiteEvent.where("#{where_case} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").count
          forecasting_logs = SiteEvent.where("#{where_case} AND source = '#{SiteEvent::SOURCE[:forecasting]}'").count
        else 
          real_logs = forecasting_logs = 0
          Transaction.where("created_at >= '#{month[:from]}' AND created_at <= '#{month[:to]}' AND site_id = '#{site_id}' AND source != '#{SiteEvent::SOURCE[:forecasting]}'").each do |t|
            amount    = t.amount + t.tax
            real_logs += (amount + t.advance) * t.usd_rate
          end
          real_logs = real_logs.round
          Transaction.where("happened_at >= '#{month[:from]}' AND happened_at <= '#{month[:to]}' AND site_id = '#{site_id}' AND source = '#{SiteEvent::SOURCE[:forecasting]}'").each do |t|
            amount            = t.amount + t.tax
            forecasting_logs += (amount + t.advance) * t.usd_rate
          end
          forecasting_logs = forecasting_logs.round
        end
      end

      if option == "Cumulative"
        real_events << (real_events.last.nil? ? real_logs : real_logs + real_events.last)
        forecasting_events << (forecasting_events.last.nil? ? forecasting_logs : forecasting_logs + forecasting_events.last)
      else
        real_events << real_logs
        forecasting_events << forecasting_logs
      end
      total_events << (real_events.last + forecasting_events.last)
    end

    month_series = months.map{|month| month[:month]}
    month_series.unshift(0)
    real_events.unshift(0)
    total_events.unshift(0)
    @chart = LazyHighCharts::HighChart.new("line") do |f|
      f.chart(defaultSeriesType: "line", zoomType: 'x', marginRight: 20)
      f.legend(borderWidth: 1, borderRadius: 5, padding: 15)
      f.title(text: "#{event_id} Logs Report", margin: 30)
      f.xAxis(categories: month_series, showFirstLabel: false, tickWidth: 0, startOnTick: false, endOnTick: false, minPadding: 0, maxPadding: 0, min: 0, max: xAxis_max_value(month_series.count))
      f.yAxis(
          title: {text: "Event Logs", margin: 10},
          min: 0, 
          labels:{format: "{value}"}
      )
      f.scrollbar(scrollbar_options(month_series.count))
      f.plotOptions(
          line: {
              animation: false,
              dataLabels: {enabled: true}
          },
          series: {threshold: 0}
      )
      f.tooltip(shared: true, crosshairs: true)
      f.exporting(filename: "event_logs_report")
      f.series({name: "Total Event Logs", lineWidth: 3, marker:{radius: 5}, data: total_events})
      f.series({name: "Real Event Logs", lineWidth: 3, marker:{radius: 5}, data: real_events})
    end

    respond_to do |format|
      format.html { 
        @url_params = "from=#{from.strftime('%m/%d/%Y')}&to=#{to.strftime('%m/%d/%Y')}&vpd_country=#{vpd_country_id}&site=#{site_id}&event_id=#{event_id}&option=#{option}"
        render layout: false 
      }
      format.json { render json: ReportDatatable.new(view_context, months, real_events, forecasting_events, event_id) }
      format.csv {
        template_csv = CSV.generate(options = {col_sep: "\,"}) do |csv|
          real_events.shift
          csv << ["Month", "#Real Event Logs", "#Forecasting Event Logs", "#Total Event Logs"]
          months.each do |month|
            real_event = real_events.shift
            forecasting_event = forecasting_events.shift
            csv << [month[:month], real_event, forecasting_event, real_event+forecasting_event]
          end
        end
        send_data template_csv, filename: "report_#{Time.now.to_date.strftime("%Y_%m_%d")}.csv"
      }
    end    
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  # Private: Set scrollbar options for highcharts
  def scrollbar_options(data_count)
    {
      enabled: data_count > 10 ? true : false,
      height: 20,
      minWidth: 20,
      barBackgroundColor: 'gray',
      barBorderRadius: 7,
      barBorderWidth: 0,
      buttonBackgroundColor: 'gray',
      buttonBorderWidth: 0,
      buttonBorderRadius: 7,
      trackBackgroundColor: 'none',
      trackBorderWidth: 1,
      trackBorderRadius: 8,
      trackBorderColor: '#CCC'
    }
  end

  # Private: Set xAxis max option value for highcharts
  def xAxis_max_value(data_count)
    data_count > 10 ? 9 : data_count-1    
  end
end
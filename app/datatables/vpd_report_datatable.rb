class VpdReportDatatable
    delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, vpd)
    @view = view
    @vpd  = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: reports.count,
      iTotalDisplayRecords: reports.total_entries,
      aaData: data.compact
    }
  end

private
  def data    
    reports.map do |report|
      [
        link_to(report.name, "javascript: show_report('/dashboard/vpd/#{@vpd.id.to_s}/reports/#{report.id.to_s}')"),
        "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
            <button class='btn btn-xs #{report.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{report.id.to_s}' data-status='1' data-type='VpdReport'>Yes</button>
            <button class='btn btn-xs #{report.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{report.id.to_s}' data-status='0' data-type='VpdReport'>No</button>
          </div>".html_safe,
        "row_" + report.id.to_s
      ]
    end  
  end

  def reports
    @reports ||= fetch_reports
  end

  def fetch_reports
    reports = params[:show_option].strip == "Include disabled"  ?  VpdReport.where(vpd: @vpd, status: 1) : @vpd.vpd_reports

    reports.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10
  end

  def sort_column
    columns = %w[name]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
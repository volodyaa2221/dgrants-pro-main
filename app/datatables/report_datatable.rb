class ReportDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, months, real_events, forecasting_events, event_id)
    @view               = view
    @months             = months
    real_events.shift
    @real_events        = real_events
    @forecasting_events = forecasting_events
    @event_id           = event_id
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: table_data.count,
      iTotalDisplayRecords: table_data.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    all_data = table_data.map do |row_data|
      [          
        row_data[:month],
        (row_data[:real_events].present?  &&  row_data[:real_events] >= 0) ? row_data[:real_events] : '',
        (row_data[:forecasting_events].present?  &&  row_data[:forecasting_events] >= 0) ? row_data[:forecasting_events] : '',
        row_data[:real_events] + row_data[:forecasting_events],
        "row_"+ row_data[:month].to_s
      ]
    end
  end

  def table_data
    @table_data ||= fetch_table_data
  end

  def fetch_table_data
    table_data = @months.map do |month|
      {month: month[:month], real_events: @real_events.shift, forecasting_events: @forecasting_events.shift}
    end

    if params[:sSearch].present?
      table_data = table_data.select{|x| x[:month] =~ /^.*#{params[:sSearch]}.*$/i}
    end

    if sort_column == "real_events"
      table_data = sort_direction=="asc" ? table_data.sort_by{|e| value(e[:real_events])} : table_data.sort_by{|e| -value(e[:real_events])}
    elsif sort_column == "forecasting_events"
      table_data = sort_direction=="asc" ? table_data.sort_by{|e| value(e[:forecasting_events])} : table_data.sort_by{|e| -value(e[:forecasting_events])}
    elsif sort_column == "total_events"      
      table_data = sort_direction=="asc" ? table_data.sort_by{|e| value(e[:real_events]+e[:forecasting_events])} : table_data.sort_by{|e| -value(e[:real_events]+e[:forecasting_events])}
    end
    table_data.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 50
  end

  def sort_column
    columns = %w[month real_events forecasting_events total_events]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def value(val)
    val.present? ? val : 0
  end
end
class PassthroughDatatable
  include Dashboard::DocumentFileHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site)
    @view     = view
    @user     = user
    @site     = site
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: passthroughs.count,
      iTotalDisplayRecords: passthroughs.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    site_id = @site.id.to_s
    symbol  = @site.site_schedule.vpd_currency.symbol
    status_labels = ["Disabled", "Pending", "Approved"]
    passthroughs.map do |passthrough|
      status = passthrough.status > 0
      invoice_file = passthrough.invoice_file
      [
        passthrough.created_at.strftime('%e %b %Y'),
        "<p title='#{passthrough.description}'>#{passthrough.description.truncate(40)}</p>",
        passthrough.budget_name,
        "#{symbol} #{currency_format(passthrough.amount)}",
        status ? link_to(status_labels[passthrough.status], "/dashboard/site/#{site_id}/passthroughs/#{passthrough.id.to_s}/edit", remote: true) : status_labels[passthrough.status],
        invoice_file.present? ? invoice_file_link_with_icon(invoice_file, nil, @view, false) : "No File",
        "row_#{passthrough.id.to_s}"
      ]
    end
  end

  def passthroughs
    @passthroughs ||= fetch_passthroughs
  end

  def fetch_passthroughs
    if params[:sSearch].present?
      where_case = "(budget_name LIKE :search_param OR description LIKE :search_param) AND site_id = #{@site.id}"
      passthroughs = Passthrough.where(where_case, search_param: "%#{params[:sSearch]}%").order(created_at: :desc) 
    else
      passthroughs = Passthrough.where(site: @site).order(created_at: :desc)
    end

    passthroughs.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[created_at description budget_name amount status]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def currency_format(x)
    @view.number_to_currency(x, unit: '')
  end
end
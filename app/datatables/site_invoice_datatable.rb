class SiteInvoiceDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site)
    @view = view
    @user = user
    @site = site
    @trial_editable = @user.trial_editable?(@site.trial)
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: invoices.count,
      iTotalDisplayRecords: invoices.total_entries+1,
      aaData: data.compact
    }
  end

private
  def data
    site_id = @site.id.to_s
    symbol  = @site.site_schedule.vpd_currency.symbol

    all_data = invoices.map do |invoice|
      # status_label = @trial_editable ? link_to("#{invoice.status_label}", @view.edit_dashboard_site_invoice_path(@site, invoice), remote: true)
      #                                : invoice.status_label
      [
        invoice.created_at.strftime('%e %b %Y'),   
        link_to("INVOICE ##{invoice.invoice_no}", "javascript: show_invoice('/dashboard/site/#{site_id}/invoices/#{invoice.id.to_s}')"),
        "#{symbol}  #{@view.number_to_currency(invoice.amount.round(2), unit: '')}",
        invoice.status_label,
        # status_label,
        "row_#{invoice.id.to_s}"
      ]
    end

    past, amounts, balance = @site.invoice_amounts(nil)
    all_data.unshift([
      "N/A", 
      link_to("CURRENT INVOICE", "javascript: show_invoice('/dashboard/site/#{site_id}/invoices/new')"),
      "#{balance>=0 ? '' : '-'}#{symbol}  #{@view.number_to_currency(balance.abs.round(2), unit: '')}",
      "ACTIVE",
      "row_first"
    ])
  end

  def invoices
    @invoices ||= fetch_invoices
  end

  def fetch_invoices
    invoices = Invoice.where(site: @site).order(created_at: :desc)

    invoices.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[created_at invoice_no amount status]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
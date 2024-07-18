class SiteTransactionDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site)
    @view = view
    @user = user
    @site = site
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: transactions.count,
      iTotalDisplayRecords: transactions.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    site_id = @site.id.to_s
    symbol  = @site.site_schedule.vpd_currency.symbol
    transactions.map do |transaction|
      desc = nil
      if transaction.type == Transaction::TYPE[:patient_event]
        desc = link_to("#{transaction.type_id}+#{transaction.patient_id}", "javascript: goto_schedule()")
      elsif transaction.type == Transaction::TYPE[:holdback]  ||  transaction.type == Transaction::TYPE[:withholding]
        desc = transaction.type_id
      else
        desc = link_to(transaction.type_id, "javascript: goto_schedule()")
      end

      earned    = transaction.payable ? transaction.earned : 0
      retained  = transaction.payable ? transaction.retained : 0
      advance   = transaction.payable ? transaction.advance : 0
      payables  = transaction.payables
      tax_label = "incl. #{transaction.tax>=0 ? '' : '-'}#{symbol} #{@view.number_to_currency(transaction.tax.abs, unit: '')} tax"

      invoice = transaction.invoice
    invoice_link = if invoice.present?
        link_to(invoice.status_label, "javascript: goto_invoice('/dashboard/site/#{site_id}/invoices/#{invoice.id.to_s}')").html_safe
      else
        if transaction.included == 1
          link_to("INVOICED", "javascript: goto_invoice('/dashboard/site/#{site_id}/invoices/new')").html_safe
        else
          link_to("APPROVE", "javascript: goto_invoice('/dashboard/site/#{site_id}/invoices/new?waiting_trans_id=#{transaction.id}')").html_safe
        end
      end

      [
        transaction.transaction_id,
        transaction.created_at.strftime('%e %b %Y'),
        desc,
        "<p title='#{tax_label}'>#{earned>=0 ? '' : '-'}#{symbol}  #{@view.number_to_currency(earned.abs, unit: '')}</p>",
        "#{retained>=0 ? '' : '-'}#{symbol}  #{@view.number_to_currency(retained.abs, unit: '')}",
        "#{advance>=0 ? '' : '-'}#{symbol}  #{@view.number_to_currency(advance.abs, unit: '')}",
        "#{payables[:payable]>=0 ? '' : '-'}#{symbol}  #{@view.number_to_currency(payables[:payable].abs, unit: '')}",
        invoice_link,
        transaction.status,
        "row_#{transaction.id.to_s}"
      ]
    end
  end

  def transactions
    @transactions ||= fetch_transactions
  end

  def fetch_transactions
    transactions = Transaction.where("site_id = #{@site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").order(created_at: :desc)

    transactions.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[transaction_id created_at type_id amount]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
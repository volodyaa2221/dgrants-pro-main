class SiteEntryDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site, type=0)
    @view = view
    @user = user
    @site = site
    @type = type
    @mode = site.site_schedule.nil? || site.site_schedule.mode
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: entries.count,
      iTotalDisplayRecords: entries.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    site_id = @site.id.to_s
    symbol  = @site.site_schedule.vpd_currency.symbol
    entries.map do |entry|
      status = entry.status > SiteEntry::STATUS[:disabled]
      if @mode  # editable mode
        if entry.status == SiteEntry::STATUS[:payable]  # payable entry
          entry_label   = entry.event_id 
          status_label  = link_to("<i class='fa fa-trash fa-lg'></i>".html_safe, "javascript: update_data('#{entry.id.to_s}', false, 'Payment Entry', 'payment entry')")
        elsif entry.status == SiteEntry::STATUS[:editable]  # editable entry
          entry_label   = link_to(entry.event_id, "/dashboard/site/#{site_id}/entries/#{entry.id.to_s}/edit", remote: true)
          status_label  = link_to("<i class='fa fa-trash fa-lg'></i>".html_safe, "javascript: update_data('#{entry.id.to_s}', true, 'Payment Entry', 'payment entry')")
        else  # disabled entry 
          entry_label   = entry.event_id
          status_label  = ''
        end
      else      # payable mode
        entry_label   = entry.event_id
        status_label  = ''
      end
      entry_title = "#{entry.user.name} saved on #{entry.updated_at.strftime('%m/%d/%Y')}"
      ledger_label = entry.vpd_ledger_category.present? ? entry.vpd_ledger_category.name : nil
      entry_label = "<p title='#{entry_title}'>#{entry_label}<br/>#{ledger_label}</p>"

      transaction_labels = Transaction.where("site_entry_id = #{entry.id} AND status != #{Transaction::STATUS[:disabled]} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").order(created_at: :desc).map do |transaction|
        event_id = transaction.site_event.id.to_s
        happened_at_label = "happened at #{transaction.happened_at.strftime('%e %b %Y')}" 
        if @type == 0
          transaction_label = link_to(transaction.type_id, "javascript: goto_event_log('#{event_id}')", title: happened_at_label)
        else
          transaction_label = link_to("#{transaction.type_id}+#{transaction.patient_id}", "javascript: goto_event_log('#{event_id}')", title: happened_at_label)
        end
        invoice = transaction.invoice
        created_at_label = invoice.present? ? "submitted at #{invoice.created_at.strftime('%e %b %y')}" : nil
        invoice_label = invoice.present? ? link_to("(#{invoice.invoice_no})", "javascript: goto_invoice('/dashboard/site/#{site_id}/invoices/#{invoice.id.to_s}')", title: created_at_label) 
                                         : link_to("(INVOICE)", "javascript: goto_invoice('/dashboard/site/#{site_id}/invoices/new')", title: "active").html_safe
        (status && transaction.status==Transaction::STATUS[:normal]) ? "#{transaction_label} #{invoice_label}" : "<del>#{transaction_label} #{invoice_label}</del>"
      end
      transaction_label = transaction_labels.join("<br/>").html_safe

      start_date  = (entry.start_date.nil?  ||  entry.start_date == TrialEntry::DATE[:forever_start]) ? '' : "CONTRACT: #{entry.start_date.strftime('%m/%d/%Y')}"
      end_date    = (entry.end_date.nil?  ||  entry.end_date == TrialEntry::DATE[:forever_end]) ? '' : "END:&nbsp;&nbsp;&nbsp;&nbsp;#{entry.end_date.strftime('%m/%d/%Y')}"
      date_period = start_date.present? ? "#{start_date}<br/>#{end_date}" : end_date
      date_period = status ? date_period.html_safe : "<del>#{date_period}</del>".html_safe

      amount = !entry.amount.zero? ? "%0.2f" % entry.amount : nil
      tax_rate = !entry.tax_rate.zero? ? "%0.2f" % entry.tax_rate : nil
      advance = !entry.advance.zero? ? "%0.2f" % entry.advance : nil

      [ 
        status ? entry_label : "<del>#{entry_label}</del>".html_safe,
        symbol,
        status ? amount : "<del>#{amount}</del>".html_safe,
        tax_rate.nil? ? nil : (status ? "#{tax_rate} %" : "<del>#{tax_rate} %</del>".html_safe),
        advance.nil? ? nil : symbol,
        status ? advance : "<del>#{advance}</del>".html_safe,
        date_period,
        entry.event_cap,
        transaction_label,
        status_label,
        "row_#{entry.id.to_s}"
      ]
    end
  end

  def entries
    @entries ||= fetch_entries
  end

  def fetch_entries
    entries = SiteEntry.where(site: @site, type: @type).order(status: :desc, updated_at: :desc)

    entries.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10000
  end

  def sort_column
    columns = %w[event_id currency amount tax_rate currency advance]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
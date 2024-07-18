class TrialEntryDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, trial, schedule, type=0)
    @view     = view
    @user     = user
    @trial    = trial
    @schedule = schedule
    @type     = type
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
    trial_id = @trial.id.to_s
    symbol   = @schedule.vpd_currency.present? ? @schedule.vpd_currency.symbol : "$"
    entries.map do |entry|
      status = entry.status > 0
      if status
        entry_label   = link_to(entry.event_id, "/dashboard/trial/#{trial_id}/entries/#{entry.id.to_s}/edit", remote: true)
        status_label  = link_to("<i class='fa fa-trash fa-lg'></i>".html_safe, "javascript: update_data('#{entry.id.to_s}', 'Payment Entry', 'payment entry')")
      else   
        entry_label   = entry.event_id
        status_label  = ''
      end
      entry_title = "#{entry.user.name} saved on #{entry.updated_at.strftime('%m/%d/%Y')}"
      ledger_label = entry.vpd_ledger_category.present? ? entry.vpd_ledger_category.name : nil
      entry_label = ledger_label.present? ? "<p title='#{entry_title}'>#{entry_label}<br/>#{ledger_label}</p>" : "<p title='#{entry_title}'>#{entry_label}</p>"
      
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
        status_label,
        "row_#{entry.id.to_s}"
      ]
    end
  end

  def entries
    @entries ||= fetch_entries
  end

  def fetch_entries
    entries = TrialEntry.where(trial_schedule: @schedule, type: @type).order(status: :desc, updated_at: :desc)

    entries.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 1000
  end

  def sort_column
    columns = %w[event_id currency amount tax_rate currency advance]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
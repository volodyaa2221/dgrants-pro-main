class InvoiceTranDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site, invoice, transaction_ids=nil)
    @view     = view
    @user     = user
    @site     = site
    @invoice  = invoice
    @editalbe = @user.site_editable?(@site)
    @transaction_ids = transaction_ids
    @hidden_data     = {overhead: nil, withholding: nil}
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: transactions.count,
      iTotalDisplayRecords: transactions.total_entries,
      aaData: data.compact
    }
  end

  def data_on_transaction_hidden
    data
    @hidden_data
  end

private
  def data
    site_id   = @site.id.to_s
    schedule  = @site.site_schedule 
    symbol    = schedule.vpd_currency.symbol

    total_amount = 0
    total_tax = 0
    total_retained_amount = 0
    total_retained_tax = 0
    total_payable_amount = 0
    total_payable_tax = 0

    all_data = transactions.map do |transaction|
      desc = nil
      if transaction.type == Transaction::TYPE[:patient_event]
        desc = link_to("#{transaction.type_id}+#{transaction.patient_id}", "javascript: goto_schedule()")
      elsif transaction.type == Transaction::TYPE[:holdback]  ||  transaction.type == Transaction::TYPE[:withholding]
        desc = transaction.type_id
      else
        desc = link_to(transaction.type_id, "javascript: goto_schedule()")
      end
      if transaction.advance > 0
        desc = "#{desc}<br/>(INCLUDES #{transaction.advance>0 ? '' : '-'}#{symbol} #{currency_format(transaction.advance.abs)} ADVANCE)".html_safe
      end

      if transaction.payable? && transaction.included != 0
        amount  = transaction.type == Transaction::TYPE[:withholding]  ?  0 : transaction.amount
        tax     = transaction.tax
        retained_amount = transaction.retained_amount
        retained_tax    = transaction.retained_tax
      else
        amount  = 0
        tax     = 0
        retained_amount = 0
        retained_tax    = 0
      end

      payables = transaction.payables
      total_amount  += amount
      total_tax     += tax
      total_retained_amount += transaction.retained_amount
      total_retained_tax    += transaction.retained_tax
      total_payable_amount  += (transaction.included != 0  ?  payables[:payable_amount] : 0)
      total_payable_tax     += (transaction.included != 0  ?  payables[:payable_tax] : 0)

      if @editalbe
        switch_label = "<div class='btn-group btn-switch' data-update-url='/dashboard/site/#{site_id}/invoices/switch_transaction'>
          <button class='btn btn-xs #{transaction.included != 0 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{transaction.id.to_s}' data-included='1'>Yes</button>
          <button class='btn btn-xs #{transaction.included == 0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{transaction.id.to_s}' data-included='0'>No</button>
        </div>".html_safe
      else
        switch_label = transaction.included!=0 ? "Yes" : "No"
      end
      row_id = "row_#{transaction.id.to_s}"

      [
        transaction.transaction_id,
        desc,
        "#{amount>=0 ? '' : '-'}#{symbol} #{currency_format(amount)} #{tax_format(tax)}",
        "#{retained_amount>=0 ? '' : '-'}#{symbol} #{currency_format(retained_amount)} #{tax_format(retained_tax)}",
        "#{payables[:payable_amount]>=0 ? '' : '-'}#{symbol} #{currency_format(payables[:payable_amount])} #{tax_format(payables[:payable_tax])}",
        switch_label,
        transaction.included == 0 ? "lightgrey" : nil,
        transaction.status == Transaction::STATUS[:disabled] ? "red" : nil,
        row_id
      ]
    end

    all_data << [
      '',
      "<b>SUBTOTAL<b>".html_safe,
      "#{total_amount>=0 ? '' : '-'}#{symbol} #{currency_format(total_amount)} #{tax_format(total_tax)}",
      total_retained_amount==0 ? "" : ("#{total_retained_amount>=0 ? '' : '-'}#{symbol} #{currency_format(total_retained_amount)} #{tax_format(total_retained_tax)}"),
      "#{total_payable_amount>=0 ? '' : '-'}#{symbol} #{currency_format(total_payable_amount)} #{tax_format(total_payable_tax)}",
      nil,
      nil,
      nil,
      "row_subtotal"
    ]
    @hidden_data[:subtotal] = all_data[-1]

    total_earned    = total_amount + total_tax
    total_retained  = total_retained_amount + total_retained_tax
    total_payable   = total_payable_amount + total_payable_tax
    if @invoice.present?
      overhead = @invoice.overhead
      withholding = @invoice.withholding
      if @invoice.type == Invoice::TYPE[:normal]
        total_payable += (overhead + withholding)
      else
        total_payable = @invoice.amount
      end
    else
      overhead_rate = schedule.overhead_rate
      overhead = (overhead_rate.present? && overhead_rate > 0) ? total_payable * overhead_rate / 100.0 : 0
      total_payable += overhead
      withholding_rate = schedule.withholding_rate
      withholding = (withholding_rate.present? && withholding_rate > 0) ? total_payable * withholding_rate / (-100.0) : 0
      total_payable += withholding
    end
    if overhead.present? && overhead != 0
      all_data << [
        '',
        "<b>OVERHEAD (#{schedule.overhead_rate}%)<b>".html_safe,
        '',
        '',
        "#{overhead>=0 ? '' : '-'}#{symbol} #{currency_format(overhead.abs)}",
        nil,
        nil,
        nil,
        "row_overhead"
      ]
      @hidden_data[:overhead] = all_data[-1]
    end
    if withholding.present? && withholding != 0
      all_data << [
        '',
        "<b>WITHHOLDING TAX (#{schedule.withholding_rate}%)<b>".html_safe,
        '',
        '',
        "#{withholding>=0 ? '' : '-'}#{symbol} #{currency_format(withholding.abs)}",
        nil,
        nil,
        nil,
        "row_withholding"
      ]
      @hidden_data[:withholding] = all_data[-1]
    end
    all_data<<[
      '',
      "<b>TRANSACTION TOTAL<b>".html_safe,
      "#{total_earned>=0 ? '' : '-'}#{symbol} #{currency_format(total_earned.abs)}",
      total_retained==0 ? "" : ("#{total_retained>=0 ? '' : '-'}#{symbol} #{currency_format(total_retained.abs)}"),
      "#{total_payable>=0 ? '' : '-'}#{symbol} #{currency_format(total_payable.abs)}",
      nil,
      nil,
      "#191970",
      "row_total"
    ]
    @hidden_data[:transaction_total] = all_data[-1]

    past = Transaction.past_invoices_amounts(@site, @invoice)
    balance_forward = past[:earned] - past[:retained] - past[:remitted]

    balance = total_payable + balance_forward

    all_data<<['', '', '', '', '', nil, nil, nil, "row_space"]
    all_data<<['', "PAST EARNINGS (TOTAL)", '', '', "#{past[:earned]>=0 ? '' : '-'}#{symbol} #{currency_format(past[:earned].abs)}", nil, nil, nil, "row_past_earned"]
    all_data<<['', "PAST HOLDBACK", '', '', "#{past[:retained]>=0 ? '' : '-'}#{symbol} #{currency_format(past[:retained].abs)}", nil, nil, nil, "row_past_retained"]
    all_data<<['', "PAST FUNDS REMITTED", '', '', "#{past[:remitted]>=0 ? '': '-'}#{symbol} #{currency_format(past[:remitted].abs)}", nil, nil, nil, "row_past_remitted"]
    all_data<<['', '', '', '', '', nil, nil, nil, "row_space"]
    all_data<<['', "<b>BALANCE BROUGHT FORWARD:</b>".html_safe, '', '', "<b>#{balance_forward>=0 ? '' : '-'}#{symbol} #{currency_format(balance_forward.abs)}</b>".html_safe, nil, nil, "#191970", "row_balance_brought_forward"]
    all_data<<['', "<b>TOTAL:</b>".html_safe, '', '', "<b>#{balance>=0 ? '' : '-'}#{symbol} #{currency_format(balance.abs)}</b>".html_safe, nil, nil, "#191970", "row_balance"]

    @hidden_data[:balance_forward] = all_data[-2]
    @hidden_data[:total] = all_data[-1]

    all_data
  end

  def transactions
    @transactions ||= fetch_transactions
  end

  def fetch_transactions
    if @invoice.present?
      transactions = Transaction.where("site_id = #{@site.id} AND invoice_id = #{@invoice.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}'").order(created_at: :desc)
    else
      transactions = []
      if @transaction_ids.present?
        if params[:show_option].present?
          status = params[:show_option].strip == "View Excluded Transactions"  ?  false : true
          transactions = status ? Transaction.where("id IN (#{@transaction_ids.join(",")})").order(created_at: :desc)
                                : Transaction.where("id IN (#{@transaction_ids.join(",")}) AND included != 0").order(created_at: :desc)
        else
          transactions = Transaction.where("id IN (#{@transaction_ids.join(",")})").order(created_at: :desc)
        end
      end
    end

    transactions.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10000
  end

  def sort_column
    columns = %w[type_id currency amount tax_rate currency advance]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def currency_format(x)
    @view.number_to_currency(x.abs, unit: '')
  end

  def tax_format(tax)
    if tax == 0
      nil
    else
      "#{tax>0 ? '+' : '-'} #{currency_format(tax)}"
    end
  end

end
class Dashboard::PaymentController < DashboardController
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin

  # Payment actions
  #----------------------------------------------------------------------
  # GET   /dashboard/payfile(.:format) 
  def payfile
    options   = {col_sep: "\t"}
    site_ids  = Site.where("status = 1 AND payment_verified > #{Site::PAYMENT_VERIFIED[:known_bad]}").map(:id)
    or_case   = "(status = Invoice::STATUS[:pending_queued] OR status = Invoice::STATUS[:rejected])"
    invoices  = Invoice.where("site_id IN (#{site_ids.join(",")}) AND sent_at IS NULL AND #{or_case}").order(created_at: :asc).map do |invoice|
      site    = invoice.site
      account = invoice.account
      new_balance = account.balance - invoice.amount * invoice.usd_rate
      next if new_balance < 0
      new_remitted = account.remitted + invoice.amount * invoice.usd_rate
      account.update_attributes(balance: new_balance, remitted: new_remitted)
      invoice.update_attributes(sent_at: Time.now.to_date, status: Invoice::STATUS[:pending_queued])
      trial_id = site.trial.trial_id
      [
        site.id.to_s,                                                                           # idap
        invoice.amount,                                                                         # amount
        site.site_schedule.vpd_currency.code,                                                   # submittedAmountCurrency
        invoice.id.to_s,                                                                        # refCode
        "dGrants payment| $#{trial_id} Invoice $#{invoice.invoice_no}",                         # eWalletMessage
        "TRUE",                                                                                 # ignoreThresholds
        "dGrants has initiated payment for Trial $#{trial_id} Invoice $#{invoice.invoice_no}",  # bankingMessage
        "dGrants has initiated payment for Trial $#{trial_id} Invoice $#{invoice.invoice_no}"   # emailMessage
      ]
    end

    template_csv = CSV.generate(options = {col_sep: "\,"}) do |csv|
      csv << ["idap", "amount", "submittedAmountCurrency", "refCode", "eWalletMessage", "ignoreThresholds", "bankingMessage", "emailMessage"]
      invoices.compact.each do |item|
        csv << item
      end
    end

    respond_to do |format|
      format.csv  { send_data template_csv, filename: "payfile_#{Time.now.to_date.strftime("%Y_%m_%d")}.csv" }
    end
  end

  # GET   /dashboard/new_upload(.:format) 
  def new_upload
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST   /dashboard/reconfile(.:format) 
  def reconfile
    # require "site"
    csv_file = params[:csv_file]
    headers  = CSV.read(csv_file.path, headers: true).headers
    keys = {}
    headers.each_with_index do |header, i|
      if header == "Payment Ref Code"
        keys[:invoice_id] = i
      elsif header == "Status"
        keys[:status] = i
      elsif header == "Paid Amount"
        keys[:usd_amount] = i
      elsif header == "Payment Date"
        keys[:payment_date] = i
      elsif header == "Payee ID"
        keys[:site_id] = i
      end
    end
    CSV.foreach(csv_file.path) do |row|
      next if row.include?("Payment Ref Code")
      next if row[keys[:invoice_id]].blank?
      invoice = Invoice.where(id: row[keys[:invoice_id]])
      next unless invoice.exists?
      next if row[keys[:status]].blank?

      invoice = invoice.first
      site = Site.where(id: row[keys[:site_id]])
      site = site.exists? ? site.first : invoice.site
      account = invoice.account
      old_balance = account.balance + invoice.amount * invoice.usd_rate
      old_remitted = account.remitted - invoice.amount * invoice.usd_rate

      if row[keys[:status]].casecmp("cleared").zero? || row[keys[:status]].casecmp("paid").zero?
        balance = old_balance - row[keys[:usd_amount]].to_f
        remitted = old_remitted + row[keys[:usd_amount]].to_f
        usd_rate = invoice.amount > 0  ?  (row[keys[:usd_amount]].to_f/invoice.amount).round(4) : invoice.usd_rate
        pay_at = row[keys[:payment_date]].blank? ? invoice.pay_at : Date.parse(row[keys[:payment_date]].to_s)
        if invoice.update_attributes(usd_rate: usd_rate, pay_at: pay_at, status: Invoice::STATUS[:successful], pi_dea: site.pi_dea, drugdev_dea: site.drugdev_dea) 
          site.update_attributes(payment_verified: Site::PAYMENT_VERIFIED[:known_good]) if site.payment_verified != Site::PAYMENT_VERIFIED[:known_good]
          account.update_attributes(balance: balance, remitted: remitted)
        end
      elsif row[keys[:status]].casecmp("Rejected").zero?
        if invoice.update_attributes(sent_at: nil, status: Invoice::STATUS[:rejected])
          site.update_attributes(payment_verified: Site::PAYMENT_VERIFIED[:known_bad]) if site.payment_verified != Site::PAYMENT_VERIFIED[:known_bad] 
          account.update_attributes(balance: old_balance, remitted: old_remitted)
        end
      end
    end

    respond_to do |format|
      format.js
    end
  end
end
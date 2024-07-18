class Dashboard::Site::TransactionsController < DashboardController
  include Dashboard::SiteHelper

  before_action :get_site
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create, :edit, :update]
  before_action :authenticate_site_editable_user,         except: [:index, :statement]
  before_action :authenticate_site_level_user,            only: :index

  # Site Statement(Transaction logs) actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/statement(.:format)
  def statement
    respond_to do |format|
      format.html { 
        @currency = @site.site_schedule.vpd_currency
        @past = Transaction.earnings(@site)
        @past[:owing] = @past[:earned] - @past[:retained] - @past[:remitted]
        @withholding = Invoice.withholding_amount(@site)

        render layout: params[:type] != "ajax" 
      }
      format.json { render json: SiteTransactionDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/holdback(.:format) 
  def new_holdback
    past = Transaction.earnings(@site)
    @holdback = past[:retained]
    @transaction = Transaction.new

    respond_to do |format|
      format.html 
      format.js
    end
  end

  # POST   /dashboard/site/:site_id/holdback(.:format) 
  def create_holdback
    retained = params[:transaction][:retained].to_f * (-1)
    transaction = @site.transactions.build(type: Transaction::TYPE[:holdback], type_id: "Holdback Release", happened_at: Time.now.to_date,
                                          retained_amount: retained, retained: retained, usd_rate: @site.site_schedule.currency.rate, 
                                          source: SiteEvent::SOURCE[:manual], vpd: @site.vpd)
    if transaction.save
      data = {success:{msg: "Transaction Added"}}
    else
      key, val = transaction.errors.messages.first
      data = {failure:{msg: entry.errors.full_messages.first, element_id: "transaction_retained"}}
    end

    render json: data
  end

  # GET   /dashboard/site/:site_id/withholding(.:format) 
  def new_withholding
    @withholding = Invoice.withholding_amount(@site)
    @payment_type = params[:payment_type]
    @transaction = Transaction.new

    respond_to do |format|
      format.html 
      format.js
    end
  end

  # POST   /dashboard/site/:site_id/withholding(.:format) 
  def create_withholding
    amount = params[:transaction][:withholding].to_f
    if params[:payment_type] == "0" # Reverse Withholding(create withholding release transaction)
      transaction = @site.transactions.build(type: Transaction::TYPE[:withholding], type_id: "Withholding Release", happened_at: Time.now.to_date,
                                            withholding: amount, usd_rate: @site.site_schedule.currency.rate, 
                                            source: SiteEvent::SOURCE[:manual], vpd: @site.vpd)
      if transaction.save
        data = {success:{msg: "Reverse Withholding Transaction", title: "Transaction Added"}}
      else
        key, val = transaction.errors.messages.first
        data = {failure:{msg: entry.errors.full_messages.first, element_id: "transaction_amount"}}
      end
    else # Remit Withholding(create debit posting)
      account = @site.trial.account
      currency = @site.site_schedule.currency
      # Create invoice as paid_offline for debit posting 
      invoice = @site.invoices.build(invoice_no: get_invoice_no, amount: amount, included_tax: 0, overhead: 0, withholding: 0, usd_rate: currency.rate,
                                    pay_at: Time.now.to_date, type: Invoice::TYPE[:withholding], account: account, currency: currency, vpd: @site.vpd)
      if invoice.save
        data = {success:{msg: "Remit Withholding Invoice", title: "Invoice Added"}}
      else
        data = {failure:{msg: invoice.errors.full_messages.first}}
      end    
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  def get_invoice_no
    invoice_no = Invoice.where(site: @site, type: Invoice::TYPE[:withholding]).order(created_at: :desc).map(:invoice_no)
    if invoice_no.count > 0
      invoice_no = invoice_no.first
      prefix  = invoice_no.gsub(/\d+/, '').squeeze(' ').strip # Remove number letters
      no      = invoice_no.gsub(/[^\d]/, '').to_i + 1         # Get only number letters
      no      = no.to_s.rjust(4, '0')
      invoice_no = "#{prefix} #{no}"
    else
      invoice_no = "WITHHOLDING 0001"
    end
  end
end
class Dashboard::Site::InvoicesController < DashboardController
  include Dashboard::SiteHelper
  include Dashboard::DocumentFileHelper

  before_action :get_site,                                except: [:edit, :update]
  before_action :authenticate_verify_user
  before_action :authenticate_site_details_editable_user, only: [:new, :create]
  before_action :authenticate_site_editable_user,         except: [:index, :new, :edit, :update, :show]
  before_action :authenticate_site_level_user,            only: :index

  # Site Statement(Transaction logs) actions
  #----------------------------------------------------------------------
  # GET   /dashboard/site/:site_id/invoices(.:format) 
  def index
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: SiteInvoiceDatatable.new(view_context, current_user, @site) }
    end
  end

  # GET   /dashboard/site/:site_id/invoices/new(.:format) 
  def new
    if params[:waiting_trans_id].present?
      transaction = Transaction.where(id: params[:waiting_trans_id]).first
      if transaction.present?
        transaction.update_attributes(included: 1)
      end
    end
    all_transactions = Transaction.where("site_id = #{@site.id} AND invoice_id IS NULL AND source != '#{SiteEvent::SOURCE[:forecasting]}'")
    @transaction_ids = all_transactions.where("included != 0").map {|t| t.id.to_s}
    respond_to do |format|
      format.html {
        @invoice = Invoice.new
        @symbol  = @site.site_schedule.vpd_currency.symbol
        past_invoices_amounts(nil)

        render layout: params[:type] != "ajax" 
      }

      format.json { render json: InvoiceTranDatatable.new(view_context, current_user, @site, nil, all_transactions.map {|t| t.id.to_s}) }
    end
  end

  # POST /dashboard/site/:site_id/invoices(.:format)
  def create
    transaction_ids = params[:transaction_ids].split(',')
    invoice = @site.invoices.build(invoice_params)
    @result = nil
    if invoice.save
      if invoice.type == Invoice::TYPE[:normal] # Not Remit Withholding 
        Transaction.where(id: transaction_ids).update_all(invoice_id: invoice.id)
      end
      if params[:invoice_file].present?
        invoice.create_invoice_file(file: params[:invoice_file])
      end
      @result = {success: true, msg: "Invoice Submitted", name:invoice.invoice_no}
    else
      @result = {success: false, msg: invoice.errors.full_messages.first }
    end

    respond_to do |format|
      format.js
    end
  end

  # GET   /dashboard/site/:site_id/invoices/:id(.:format) 
  def show
    @invoice = Invoice.find(params[:id])

    respond_to do |format|
      format.html { 
        set_invoice_status_list

        @invoice_status2 = Invoice::STATUS.map do |k, v|
          Invoice.status_label(v)
        end

        @symbol  = @invoice.currency.symbol
        @amount  = @invoice.amount
        @tax     = @invoice.included_tax
    
        render layout: params[:type] != "ajax" 
      }

      format.json { render json: InvoiceTranDatatable.new(view_context, current_user, @site, @invoice) }
    end
  end

  # GET   /dashboard/site/:site_id/invoices/:id/edit(.:format) 
  def edit
    @invoice = Invoice.find(params[:id])
    approver_type = params[:approver_type].to_i
    set_invoice_status_list(approver_type)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/site/:site_id/invoices/:id(.:format) 
  def update
    invoice = Invoice.find(params[:id])
    status  = params[:invoice][:status].to_i
    if status == Invoice::STATUS[:paid_offline]
      site = invoice.site
      updating_params = {status: status, pi_dea: site.pi_dea, drugdev_dea: site.drugdev_dea}
    else
      updating_params = {status: status}
    end
    if invoice.update_attributes(updating_params)
      data = {success:{msg: "Invoice Updated", name: invoice.invoice_no}}
    else
      key, val = invoice.errors.messages.first
      data = {failure:{msg: invoice.errors.full_messages.first, element_id: "invoice_#{key}"}}
    end

    render json: data
  end

  # Other actions
  #----------------------------------------------------------------------
  # POST  /dashboard/site/:site_id/invoices/switch_transaction(.:format)
  def switch_transaction
    @transaction_ids = params[:transaction_ids].reject(&:blank?) if params[:transaction_ids].present?
    transaction = Transaction.find(params[:transaction_id])
    if transaction.update_attributes(included: params[:included])
      table_data = InvoiceTranDatatable.new(view_context, current_user, @site, nil, @transaction_ids).data_on_transaction_hidden
      past_invoices_amounts(nil)
      symbol  = @site.site_schedule.vpd_currency.symbol
      data = {success: {table_data: table_data, 
                        form_data: {amount: @balance, included_tax: @amounts[:payable_tax], 
                                    overhead: @amounts[:overhead], withholding: @amounts[:withholding], 
                                    pay_amount: "#{symbol} #{view_context.number_to_currency(@balance, unit: '')} ".html_safe,
                                    pay_tax: "(incl. #{symbol} #{view_context.number_to_currency(@amounts[:payable_tax], unit: '')} tax)".html_safe}}}
    else
      data = {failure: {msg: transaction.errors.full_messages.first}}
    end

    render json: data
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  def set_invoice_status_list(approver_type=0)
    @invoice_status = Invoice::STATUS.map do |k, v|
      [Invoice.status_label(v), v]
    end
    @invoice_status.delete_at(@invoice_status.count-2) # Remove successful
    @invoice_status.delete_at(@invoice_status.count-2) # Remove rejected
    @invoice_status.delete_at(@invoice_status.count-1) if approver_type == 0
  end

  def past_invoices_amounts(invoice)
    @past, @amounts, @balance = @site.invoice_amounts(invoice, @transaction_ids)
    @balance = 0 if @balance < 0
  end

  def invoice_params
    params[:invoice][:pay_at]      = Time.now.to_date + @site.site_schedule.payment_terms
    params[:invoice][:account_id]  = @site.trial.account.id.to_s
    currency = @site.site_schedule.currency
    params[:invoice][:currency_id] = currency.id.to_s
    vpd_currency = @site.site_schedule.vpd_currency
    params[:invoice][:vpd_currency_id] = vpd_currency.id.to_s
    params[:invoice][:usd_rate]    = currency.rate
    params[:invoice][:vpd_id]      = @site.vpd.id
    params.require(:invoice).permit(:invoice_no, :amount, :included_tax, :overhead, :withholding, :pay_at, :usd_rate, :account_id, :currency_id, :vpd_currency_id).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:invoice][:vpd_id]
    end
  end
end
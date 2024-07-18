class Transaction < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Constants
  #----------------------------------------------------------------------
  TYPE    = {static_event: 0, patient_event: 1, passthrough: 2, holdback: 3, withholding: 4}
  STATUS  = {disabled: 0, reversed: 1, normal: 2}

  # Associations
  #----------------------------------------------------------------------
  belongs_to :vpd
  belongs_to :site
  belongs_to :site_entry
  belongs_to :site_event
  belongs_to :invoice
  belongs_to :site_passthrough_budget
  belongs_to :passthrough

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :site, :happened_at

  # Scopes
  #----------------------------------------------------------------------
  # scope :activated_transactions, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_create :setup_transaction
  after_update :sync_for_update
  after_destroy :destroy_transaction

  # Class methods
  #----------------------------------------------------------------------
  # Public: Get past amounts(earned, retained and advance) of transactions
  def self.past_invoices_amounts(site, invoice)
    if invoice.present?
      past_invoices = Invoice.where("site_id = #{site.id} AND created_at < '#{invoice.created_at}' AND type = #{Invoice::TYPE[:normal]}")
      past_transactions = Transaction.where("site_id = #{site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND payable = true AND invoice_id IN (#{past_invoices.map(&:id).join(",")})") if past_invoices.present?
      remitted_withholding = Invoice.where("site_id = #{site.id} AND created_at < '#{invoice.created_at}' AND type = #{Invoice::TYPE[:withholding]}").sum(:amount)
    else
      past_invoices = Invoice.where(site: site, type: Invoice::TYPE[:normal])
      past_transactions = Transaction.where("site_id = #{site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND payable = true AND invoice_id IS NOT NULL AND included != 0")
      remitted_withholding = Invoice.where(site: site, type: Invoice::TYPE[:withholding]).sum(:amount)
    end
    earned = (past_transactions.present? ? past_transactions.sum(:earned) : 0.0) + remitted_withholding
    retained = past_transactions.present? ? past_transactions.sum(:retained) : 0.0
    remitted = past_invoices.present? ? past_invoices.where("status < #{Invoice::STATUS[:deleted]}").sum(:amount) : 0.0

    {earned: earned, retained: retained, remitted: remitted}
  end

  # Public: Get amounts of the given invoice
  def self.invoice_amounts(site, invoice, transaction_ids=nil)
    if invoice.present?
      invoice_amount = invoice.amount
      invoice_payable_tax = invoice.included_tax
      invoice_overhead = invoice.overhead
      invoice_withholding = invoice.withholding
    else
      transactions = transaction_ids.nil? ? Transaction.where("site_id = #{site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND payable = true AND invoice_id IS NULL AND included != 0") 
                                          : (transaction_ids.present? ? Transaction.where("id IN (#{transaction_ids.join(",")}) AND included != 0") : [])
      invoice_earned = invoice_retained = invoice_advance = invoice_payable_tax = 0
      if transactions.present?
        invoice_earned    = transactions.sum(:earned) + transactions.sum(:withholding)
        invoice_retained  = transactions.sum(:retained)
        invoice_advance   = transactions.sum(:advance)
        invoice_payable_tax = transactions.sum(:tax) - transactions.sum(:retained_tax)
      end
      invoice_payable_tax = 0 if invoice_payable_tax < 0
      invoice_amount = invoice_earned - invoice_retained + invoice_advance

      schedule = site.site_schedule
      overhead_rate = schedule.overhead_rate
      invoice_overhead = (overhead_rate.present? && overhead_rate > 0) ? invoice_amount * overhead_rate / 100.0 : 0
      invoice_amount += invoice_overhead
      withholding_rate = schedule.withholding_rate
      invoice_withholding = (withholding_rate.present? && withholding_rate > 0) ? invoice_amount * withholding_rate / (-100.0) : 0
      invoice_amount += invoice_withholding
    end

    {amount: invoice_amount, payable_tax: invoice_payable_tax, overhead: invoice_overhead, withholding: invoice_withholding}
  end

  # Public: Get earned amount of the given site
  def self.earnings(site)
    or_case1 = "(status = #{Invoice::STATUS[:paid_offline]} OR status = #{Invoice::STATUS[:successful]})"
    remitted = Invoice.where("site_id = #{site.id} AND #{or_case1}").sum(:amount)

    transactions = Transaction.where("site_id = #{site.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND payable = true")

    {earned: transactions.sum(:earned), retained: transactions.sum(:retained), advanced: transactions.sum(:advance), remitted: remitted}
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Attribute methods
  #----------------------------------------------------------------------
  def payables
    if type == TYPE[:holdback]
        payable_amount = retained_amount.abs
        payable_tax = 0
        payable = payable_amount
    elsif type == TYPE[:withholding]
        payable_amount = withholding.abs
        payable_tax = 0
        payable = payable_amount
    else
      if self.payable
        payable_amount = amount - retained_amount + advance
        payable_tax = tax - retained_tax
        payable = payable_amount + payable_tax
      else
        payable_amount = 0
        payable_tax = 0
        payable = 0
      end
    end

    {payable_amount: payable_amount, payable_tax: payable_tax, payable: payable}
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  # Callback methods
  #----------------------------------------------------------------------
  def setup_transaction
    if source != SiteEvent::SOURCE[:Forecasting]
      max_id = Transaction.maximum(:transaction_id).to_i + 1
      digits = max_id > 99999  ?  8 : 5
      max_id = max_id.to_s.rjust(digits, '0')

      amounts = get_amounts
      if type >= TYPE[:passthrough]
        payable = true
      else
        payable = self.status==STATUS[:disabled] ? self.payable : self.status==STATUS[:normal] && (site_entry.event_cap.nil? || (site_entry.event_cap.present? && site_entry.event_cap>site_entry.event_count))
      end

      if self.status == STATUS[:normal] # New Transaction
        if amount.nil? || tax.nil? || earned.nil? || retained_amount.nil? || retained_tax.nil? || retained.nil? || advance.nil?
          self.update_attributes(transaction_id: max_id, amount: amounts[:amount], tax: amounts[:tax], earned: amounts[:earned], advance: amounts[:advance], payable: payable,
                                retained_amount: amounts[:retained_amount], retained_tax: amounts[:retained_tax], retained: amounts[:retained])
        else
          self.update_attributes(transaction_id: max_id, payable: payable,
                                retained_amount: amounts[:retained_amount], retained_tax: amounts[:retained_tax], retained: amounts[:retained])
        end
        site_entry.update_attributes(event_count: site_entry.event_count+1) if type < TYPE[:passthrough] && payable
      else # Disabled Transaction
        self.update_attributes(transaction_id: max_id, payable: payable)
        if type < TYPE[:passthrough]  &&  status == STATUS[:disabled]  &&  site_entry.event_cap.present?
          if payable
            if site_entry.event_cap > site_entry.event_count-1
              next_trans = Transaction.where("site_id = #{site.id} AND site_entry_id = #{site_entry.id} AND source != '#{SiteEvent::SOURCE[:Forecasting]}' AND status = #{STATUS[:normal]} AND payable = false AND happened_at > '#{happened_at}'").order(created_at: :asc)
              if next_trans.exists?
                next_trans = next_trans.first
                next_trans.update_attributes(payable: true, invoice: nil)
              else
                site_entry.update_attributes(event_count: site_entry.event_count-1)
              end
            else
              site_entry.update_attributes(event_count: site_entry.event_count-1)
            end
          end
        end
      end
    else
      if self.status == STATUS[:normal] && amount.nil? || tax.nil? || retained_amount.nil? || retained_tax.nil? || earned.nil? || retained.nil? || advance.nil?
        amounts = get_amounts
        self.update_attributes(amount: amounts[:amount], tax: amounts[:tax], earned: amounts[:earned], advance: amounts[:advance],
                              retained_amount: amounts[:retained_amount], retained_tax: amounts[:retained_tax], retained: amounts[:retained])
      end
    end
  end

  def destroy_transaction
    if type < TYPE[:passthrough]  &&  payable  &&  status == STATUS[:normal]
      site_entry.update_attributes(event_count: site_entry.event_count-1)
    end
  end

  def get_amounts
    new_amount = amount.present? ? amount : 0
    new_tax = tax.present? ? tax : 0
    new_earned = earned.present? ? earned : 0
    new_advance = advance.present? ? advance : 0

    schedule = site.site_schedule
    if type < TYPE[:passthrough]  &&  status == STATUS[:normal]  &&  schedule.holdback_amount.present?
      past_retained = Transaction.where("site_id = #{site.id} AND source != '#{SiteEvent::SOURCE[:Forecasting]}' AND id != #{self.id}").sum(:retained)
      if past_retained >= schedule.holdback_amount
        new_retained_amount = 0
        new_retained_tax = 0
        new_retained = 0
      else
        new_retained_amount = retained_amount.present? ? retained_amount : 0
        new_retained_tax = retained_tax.present? ? retained_tax : 0
        new_retained = retained.present? ? retained : 0
      end
    else
      new_retained_amount = retained_amount.present? ? retained_amount : 0
      new_retained_tax = retained_tax.present? ? retained_tax : 0
      new_retained = retained.present? ? retained : 0
    end
    {amount: new_amount, tax: new_tax, earned: new_earned, advance: new_advance, retained_amount: new_retained_amount, retained_tax: new_retained_tax, retained: new_retained}
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_transaction_id",     type: "int(11)",          default: "NULL"},
                        { name:   "transaction_id",           type: "varchar(255)",     default: "NULL"},
                        { name:   "type",                     type: "varchar(255)",     default: "'Static Event'"},
                        { name:   "type_id",                  type: "varchar(255)",     default: "''"},
                        { name:   "patient_id",               type: "varchar(255)",     default: "NULL"},
                        { name:   "happened_at",              type: "datetime",         default: "NULL"},
                        { name:   "payable",                  type: "boolean",          default: false},
                        { name:   "amount",                   type: "float",            default: 0},
                        { name:   "tax",                      type: "float",            default: 0},
                        { name:   "earned",                   type: "float",            default: 0},
                        { name:   "advanced",                 type: "float",            default: 0},
                        { name:   "retained_amount",          type: "float",            default: 0},
                        { name:   "retained_tax",             type: "float",            default: 0},
                        { name:   "retained",                 type: "float",            default: 0},
                        { name:   "withholding",              type: "float",            default: 0},
                        { name:   "usd_rate",                 type: "float",            default: 0},
                        { name:   "paid",                     type: "boolean",          default: false},
                        { name:   "source",                   type: "varchar(255)",     default: "'Manual'"},
                        { name:   "status",                   type: "varchar(255)",     default: "'Normal'"},
                        { name:   "included",                 type: "varchar(255)",     default: "NULL"},
                        { name:   "mysql_site_id",            type: "int(11)",          default: "NULL"},
                        { name:   "mysql_site_entry_id",      type: "int(11)",          default: "NULL"},
                        { name:   "mysql_site_event_id",      type: "int(11)",          default: "NULL"},
                        { name:   "mysql_invoice_id",         type: "int(11)",          default: "NULL"},
                        { name:   "created_at",               type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",               type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "transactions"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Transaction Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    type_label = TYPE.map do |k, v|
      k.to_s.camelize
    end

    status_label = STATUS.map do |k, v|
      k.to_s.camelize
    end

    query_count=0 and queries=""
    data = Transaction.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
    data.each do |item|
      insert_query = update_query = value_query = ""
      FIELD_HASH_ARRAY.each do |field|
        # p ">>>>>>>>>>>>>field_name : #{field[:name]} => '#{item[field[:name]]}' >>>>>>>>>>>>>>>>"
        insert_query += "`#{field[:name]}`, "
        update_query += "`#{field[:name]}`="
        if field[:type] == "timestamp" || field[:type] == "datetime"
          value_query += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
          update_query += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
        elsif (field[:type] == "int(11)" && !field[:name].include?("mysql_")) || field[:type] == "boolean"
          value_query += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
          update_query += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
        else
          if field[:name].include?("mysql_")
            if field[:name] == "mysql_transaction_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "type"
            value_query += item[field[:name]].present? ? "\"#{type_label[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{type_label[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "status"
            value_query += item[field[:name]].present? ? "\"#{status_label[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{status_label[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "included"
            value_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_transaction_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_transaction_id`=#{item.id};").first
        # p ">>>>>>>>>>>>>>count #{results["count"]}>>>>>>>>>>>>>>>>>>>>"
        query = update_query if results["count"] > 0
      end
      
      queries+=query and query_count+=1
      if query_count == Vpd::BATACH_QUERY_COUNT || index == data_count-1
        connection.query(queries)
        queries="" and query_count=0
        while connection.next_result
          connection.store_result rescue ''
        end
      end
      item.sync_for_synced
    end
  end
end
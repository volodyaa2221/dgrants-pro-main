class Invoice < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Constants
  #----------------------------------------------------------------------
  TYPE   = {normal: 0, withholding: 1}
  STATUS = {needs_approval: 0, approved: 1, pending_queued: 2, paid_offline: 3, rejected: 4, successful: 5, deleted: 6} # (rejected = paid_offline)

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :vpd
  belongs_to  :currency
  belongs_to  :vpd_currency
  belongs_to  :site
  belongs_to  :account

  has_one     :invoice_file,          dependent: :destroy
  has_one     :post
  has_one     :invoice_payment_info,  dependent: :destroy 
  has_many    :transactions

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :site, :invoice_no
  validates_uniqueness_of :invoice_no, scope: :site_id, case_sensitive: false

  # Scopes
  #----------------------------------------------------------------------
  # scope :activated_invoices, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_create  :setup_invoice
  after_update  :sync_for_update
  after_destroy :clear_transactions

  # Class methods
  #----------------------------------------------------------------------
  # Public: Get total withholding amount of the given site
  def self.withholding_amount(site)
    withholding = Invoice.where("site_id = #{site.id} AND type = #{TYPE[:normal]} AND status != #{STATUS[:deleted]}").sum(:withholding)
    remitted_withholding = Invoice.where("site_id = #{site.id} AND type = #{TYPE[:withholding]} AND status != #{STATUS[:deleted]}").sum(:amount)
    reversed_withholding = Transaction.where("site_id = #{site.id} AND status = #{Transaction::STATUS[:normal]} AND type = #{Transaction::TYPE[:withholding]} AND payable = true").sum(:withholding)
    withholding += (reversed_withholding + remitted_withholding)
    withholding.round(2).abs
  end

  # Collection methods
  #----------------------------------------------------------------------

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Set all transactions invoice as nil
  def clear_transactions
    self.transactions.each do |transaction|
      transaction.update_attributes(invoice_id: nil)
    end
  end

  def self.status_label(value)
    case value
    when STATUS[:needs_approval]
      "SUBMITTED"
    when STATUS[:successful]
      "PAID"
    else
      STATUS.invert[value].to_s.humanize.upcase
    end
  end

  def status_label
    Invoice.status_label(status)
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  
  # Callback methods
  #----------------------------------------------------------------------
  def setup_invoice
    vpd = site.vpd
    self.update_attributes(status: STATUS[:approved]) if vpd.auto_amount.present?  &&  vpd.auto_amount >= usd_rate*amount
    site.update_attributes(is_invoice_overdue: 0) if site.is_invoice_overdue == 1

    # Set up payment information
    info_params = {
        site_address:         site.address,
        site_city:            site.city,
        site_state:           site.state,
        site_country:         site.country_name,
        site_postcode:        site.zip_code,
    }
    if invoice_payment_info.present?
      info_params.merge!({
          currency_code:        site.payment_info.currency_code,
          field1_label:         site.payment_info.field1_label,
          field1_value:         site.payment_info.field1_value,
          field2_label:         site.payment_info.field2_label,
          field2_value:         site.payment_info.field2_value,
          field3_label:         site.payment_info.field3_label,
          field3_value:         site.payment_info.field3_value,
          field4_label:         site.payment_info.field4_label,
          field4_value:         site.payment_info.field4_value,
          field5_label:         site.payment_info.field5_label,
          field5_value:         site.payment_info.field5_value,
          field6_label:         site.payment_info.field6_label,
          field6_value:         site.payment_info.field6_value,
          bank_name:            site.payment_info.bank_name,
          bank_street_address:  site.payment_info.bank_street_address,
          bank_city:            site.payment_info.bank_city,
          bank_state:           site.payment_info.bank_state,
          bank_country:         site.payment_info.country,
          bank_postcode:        site.payment_info.bank_postcode        
        })
    end
    invoice_payment_info = build_invoice_payment_info(info_params)
    invoice_payment_info.save
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
    if self.status_changed?  &&  (self.status == STATUS[:paid_offline]  ||  self.status == STATUS[:successful])
      self.transactions.each do |t|
        t.update_attributes(usd_rate: self.usd_rate, paid: true)
      end
    end
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_invoice_id",     type: "int(11)",          default: "NULL"},
                        { name:   "invoice_no",           type: "varchar(255)",     default: "NULL"},
                        { name:   "amount",               type: "float",            default: 0},
                        { name:   "included_tax",         type: "float",            default: 0},
                        { name:   "withholding",          type: "float",            default: 0},
                        { name:   "overhead",             type: "float",            default: 0},
                        { name:   "usd_rate",             type: "float",            default: 1},
                        { name:   "pay_at",               type: "datetime",         default: "NULL"},
                        { name:   "sent_at",              type: "datetime",         default: "NULL"},
                        { name:   "type",                 type: "varchar(255)",     default: "'Normal'"},
                        { name:   "status",               type: "varchar(255)",     default: "'Needs Approval'"},
                        { name:   "mysql_site_id",        type: "int(11)",          default: "NULL"},
                        { name:   "mysql_account_id",     type: "int(11)",          default: "NULL"},
                        { name:   "created_at",           type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",           type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "invoices"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Invoice Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    invoice_status = STATUS.map do |k, v|
      k.to_s.humanize.upcase
    end

    type_label = TYPE.map do |k, v|
      k.to_s.camelize
    end

    query_count=0 and queries=""
    data = Invoice.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
    data.each do |item|
      insert_query = update_query = value_query = ""
      FIELD_HASH_ARRAY.each do |field|
        # p ">>>>>>>>>>>>>field_name : #{field[:name]} => '#{item[field[:name]]}' >>>>>>>>>>>>>>>>"
        insert_query += "`#{field[:name]}`, "
        update_query += "`#{field[:name]}`="
        if field[:type] == "timestamp" || field[:type] == "datetime"
          value_query  += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
          update_query += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
        elsif (field[:type] == "int(11)" && !field[:name].include?("mysql_")) || field[:type] == "boolean"
          value_query  += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
          update_query += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
        else
          if field[:name].include?("mysql_")
            if field[:name] == "mysql_invoice_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "type"
            value_query  += item[field[:name]].present? ? "\"#{type_label[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{type_label[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "status"
            value_query  += item[field[:name]].present? ? "\"#{invoice_status[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{invoice_status[item[field[:name]]]}\", " : "'', "
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_invoice_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_invoice_id`=#{item.id};").first
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
class SitePassthroughBudget < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  STATUS  = {disabled: 0, payable: 1, editable: 2}

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :vpd
  belongs_to  :site
  has_many    :transactions, dependent: :destroy
  has_many    :passthroughs

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :site, :name
  validates_uniqueness_of :name, scope: :site_id
  
  # Scopes
  #----------------------------------------------------------------------
  scope :activated_budgets,   -> {where.not(status: 0)}          # payable and editable budgets
  scope :editable_budgets,    -> {where(status: 2)}           # editable budgets

  # Callbacks
  #----------------------------------------------------------------------
  after_update :sync_for_update

  # Validation methods
  #----------------------------------------------------------------------

  # Callback methods
  #----------------------------------------------------------------------

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Disable transactions when status is disabled
  def disable_transactions
    old_transactions = Transaction.where(site: site, site_passthrough_budget: self, status: Transaction::STATUS[:normal]).map{|transaction| transaction}
    old_transactions.each do |t|
      reversal_transaction = self.transactions.build(type_id: t.type_id, type: t.type, happened_at: t.happened_at,
                                                    amount: -1*t.amount, earned: -1*t.earned, usd_rate: t.usd_rate, status: Transaction::STATUS[:disabled], 
                                                    vpd: self.vpd, site: site, passthrough: t.passthrough)
      t.update_attributes(status: Transaction::STATUS[:reversed]) if reversal_transaction.save
    end
  end

  # Public: Get total approved passthrough amounts
  def total_approved_amounts
    Passthrough.where(site: site, site_passthrough_budget: self, status: Passthrough::STATUS[:approved]).sum(:amount)
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

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_site_passthrough_budget_id",   type: "int(11)",          default: "NULL"},
                        { name:   "name",                               type: "varchar(255)",     default: "NULL"},
                        { name:   "max_amount",                         type: "float",            default: 0},
                        { name:   "monthly_amount",                     type: "float",            default: 0},
                        { name:   "status",                             type: "varchar(255)",     default: "'Editable'"},
                        { name:   "mysql_site_id",                      type: "int(11)",          default: "NULL"},
                        { name:   "created_at",                         type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",                         type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "site_passthrough_budgets"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>SitePassthroughBudget Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    status_label = STATUS.map do |k, v|
      k.to_s.camelize
    end

    query_count=0 and queries=""
    data = SitePassthroughBudget.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_site_passthrough_budget_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "status"
            value_query += item[field[:name]].present? ? "\"#{status_label[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{status_label[item[field[:name]]]}\", " : "'', "
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_site_passthrough_budget_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_site_passthrough_budget_id`=#{item.id};").first
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
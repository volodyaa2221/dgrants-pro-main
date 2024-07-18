class Passthrough < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  STATUS  = {disabled: 0, pending: 1, approved: 2}

  # Associations
  #----------------------------------------------------------------------
  belongs_to :vpd
  belongs_to :site
  belongs_to :site_passthrough_budget
  
  has_one    :invoice_file, dependent: :destroy
  has_many   :transactions, dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :site, :site_passthrough_budget, :description, :amount, :happened_at
  validate :check_exceeding_budget

  # Callbacks
  #----------------------------------------------------------------------
  after_update :sync_for_update

  # Validation methods
  #----------------------------------------------------------------------
  def check_exceeding_budget
    budget = self.site_passthrough_budget

    if budget.monthly_amount > 0
      date = self.created_at.present? ? self.created_at.to_date : Time.now.to_date
      month_start_time  = Time.new(date.year, date.month, 1, 0, 0, 0)
      month_end_time    = Time.new(date.year, date.month+1, 1, 23, 59, 59).yesterday
      where_case = "#{self.id.present? ? "id != #{self.id} AND ": ""}site_id = #{self.site.id} AND site_passthrough_budget_id = #{self.site_passthrough_budget.id}"\
                   " AND status = #{STATUS[:approved]} AND updated_at >= '#{month_start_time}' AND updated_at <= '#{month_end_time}'"
      monthly_amount    = Passthrough.where(where_case).sum(:amount)
      errors.add(:amount, "Exceeds monthly budget") if monthly_amount + self.amount > budget.monthly_amount
    end

    if errors.count == 0  &&  budget.max_amount > 0
      total_amount = Passthrough.where("#{self.id.present? ? "id != #{self.id} AND ": ""}site_id = #{self.site_id} AND site_passthrough_budget_id = #{self.site_passthrough_budget_id} AND status = #{STATUS[:approved]}").sum(:amount)
      errors.add(:amount, "Exceeds max budget") if total_amount + self.amount > budget.max_amount      
    end
  end

  # Returns 0: red = please act (pending passthroughs), 1: green = nothing to act upon
  def self.has_pending?(site)
    Passthrough.where(site: site, status: STATUS[:pending]).count > 0
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Create transactions(create transactions for this passthrough)
  def create_transactions
    schedule = site.site_schedule
    rate     = schedule.currency.rate
    if schedule.present?  &&  schedule.mode == false  # if Site Schedule exists and it's mode is payable
      if !transactions.exists?  &&  site_passthrough_budget.status == SitePassthroughBudget::STATUS[:payable]
        self.transactions.create(type: Transaction::TYPE[:passthrough], type_id: budget_name, happened_at: happened_at, amount: amount, earned: amount, usd_rate: rate, 
                                vpd: self.vpd, site: site, site_passthrough_budget: site_passthrough_budget)
      end    
    end
  end

  # Public: Disable transactions(create reversal transactions)
  def disable_transactions
    old_transactions = Transaction.where(site: site, passthrough: self, type: Transaction::TYPE[:passthrough], type_id: self.budget_name, status: Transaction::STATUS[:normal]).map{|transaction| transaction}
    old_transactions.each do |t|
      reversal_transaction = self.transactions.build(type: t.type, type_id: t.type_id, happened_at: t.happened_at, amount: -1*t.amount, earned: -1*t.earned, usd_rate: t.usd_rate, status: Transaction::STATUS[:disabled], 
                                                    vpd: self.vpd, site: site, site_passthrough_budget: t.site_passthrough_budget, passthrough: t.passthrough)
      t.update_attributes(status: Transaction::STATUS[:reversed]) if reversal_transaction.save
    end
  end

  # Callback methods
  #----------------------------------------------------------------------

  # Private methods
  #----------------------------------------------------------------------
  private

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_passthrough_id",             type: "int(11)",          default: "NULL"},
                        { name:   "budget_name",                      type: "varchar(255)",     default: "NULL"},
                        { name:   "description",                      type: "varchar(255)",     default: "NULL"},
                        { name:   "amount",                           type: "float",            default: 0},
                        { name:   "happened_at",                      type: "datetime",         default: "NULL"},
                        { name:   "status",                           type: "varchar(255)",     default: "'Pending'"},
                        { name:   "mysql_site_id",                    type: "int(11)",          default: "NULL"},
                        { name:   "mysql_site_passthrough_budget_id", type: "int(11)",          default: "NULL"},
                        { name:   "created_at",                       type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",                       type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "passthroughs"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Passthrough Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    status_label = STATUS.map do |k, v|
      k.to_s.camelize
    end

    query_count=0 and queries=""
    data = Passthrough.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_passthrough_id"
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
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_passthrough_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_passthrough_id`=#{item.id};").first
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
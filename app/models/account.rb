class Account < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  DRUGDEV_REFID = "0000000"

  # Associations
  #----------------------------------------------------------------------
  belongs_to :vpd
  belongs_to :trial

  has_many   :posts,      dependent: :destroy
  has_many   :invoices,   dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validate :check_validation

  # Scopes
  #----------------------------------------------------------------------
  
  # Callbacks
  #----------------------------------------------------------------------
  after_update :sync_for_update
  
  # Validation methods
  #----------------------------------------------------------------------
  def check_validation
    if ref_id != Account::DRUGDEV_REFID  &&  self.new_record?  &&  trial.nil?
      errors.add(:trial, "can't be empty")    
    end
  end

  # Class methods
  #----------------------------------------------------------------------
  def self.new_ref_id
    charset = ('A'..'Z').to_a + ('0'..'9').to_a
    code = nil
    loop do
      code = (0...6).map { charset[SecureRandom.random_number(charset.size)] }.join
      # Array.new(6){charset.sample}.join
      # (1..6).map{|i| charset[rand(62)]}.join
      x = code.sum.to_s(16)
      code = "#{code}#{x[x.length-1]}".upcase
      break if code.present? && !Account.where(ref_id: code).exists?
    end
    code
  end
  
  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Attribute methods
  #----------------------------------------------------------------------
  def usd_amount_after_posting
    pending_amount = 0
    Invoice.where("account_id = #{id} AND sent_at IS NULL AND status <= #{Invoice::STATUS[:deleted]}").each do |invoice|
      pending_amount += invoice.amount * invoice.usd_rate
    end
    return balance - pending_amount
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

  FIELD_HASH_ARRAY =  [ { name:   "mysql_account_id",     type: "int(11)",          default: "NULL"},
                        { name:   "ref_id",               type: "varchar(255)",     default: "''"},
                        { name:   "balance",              type: "float",            default: 0},
                        { name:   "pre_post",             type: "float",            default: 0},
                        { name:   "remitted",             type: "float",            default: 0},
                        { name:   "vpd_name",             type: "varchar(255)",     default: "''"},
                        { name:   "trial_name",           type: "varchar(255)",     default: "''"},
                        { name:   "mysql_trial_id",       type: "int(11)",          default: "NULL"},
                        { name:   "created_at",           type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",           type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "accounts"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Account Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = Account.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_account_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          else
            field_name = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_account_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_account_id`=#{item.id};").first
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
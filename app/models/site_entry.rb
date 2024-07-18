class SiteEntry < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Constants
  #----------------------------------------------------------------------
  STATUS  = {disabled: 0, payable: 1, editable: 2}
  
  # Associations
  #----------------------------------------------------------------------
  belongs_to  :user # User who created this entry
  belongs_to  :vpd
  belongs_to  :vpd_ledger_category
  belongs_to  :site

  has_many    :transactions, dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :site, :event_id, :type
  
  # Scopes
  #----------------------------------------------------------------------
  scope :activated_entries,   -> {where.not(status: 0)}          # payable and editable entries
  scope :editable_entries,    -> {where(status: 2)}           # editable entries
  scope :transaction_entries, -> (type) {where(type: type)}   # static or patient entries

  # Callbacks
  #----------------------------------------------------------------------
  after_update :sync_for_update

  # Validation methods
  #----------------------------------------------------------------------
  # Checks start and end dates of an entry overlapping one's 
  #   in a collection of entries for a same patient (event_id)
  def self.check_overlap_dates(site, entry)
    or_case1 = "('#{entry.start_date}' >= start_date AND '#{entry.start_date}' <= end_date) OR "\
               "(start_date >= '#{entry.start_date}' AND start_date <= '#{entry.end_date}')"
    or_case2 = "('#{entry.end_date}' >= start_date AND '#{entry.end_date}' <= end_date) OR "\
               "(end_date >= '#{entry.start_date}' AND end_date <= '#{entry.end_date}')"
    where("site_id = #{site.id} AND event_id = '#{entry.event_id}' AND (#{or_case1} OR #{or_case2})").count > 0
  end

  # Callback methods
  #----------------------------------------------------------------------

  # Attribute methods
  #----------------------------------------------------------------------
  def disable_transactions
    old_transactions = Transaction.where(site: site, site_entry: self, status: Transaction::STATUS[:normal]).map{|transaction| transaction}
    old_transactions.each do |t|
      earned = t.amount + t.tax
      retained = t.retained_amount + t.retained_tax      
      reversal_transaction = self.transactions.build(type: t.type, type_id: t.type_id, patient_id: t.patient_id, happened_at: t.happened_at, payable: t.payable,
                                                    amount: -1*t.amount, tax: -1*t.tax, retained_amount: -1*t.retained_amount, retained_tax: -1*t.retained_tax, 
                                                    earned: -1*earned, retained: -1*retained, advance: -1*t.advance, usd_rate: t.usd_rate, source: t.source, status: Transaction::STATUS[:disabled], 
                                                    vpd: self.vpd, site: site, site_event: t.site_event)
      t.update_attributes(status: Transaction::STATUS[:reversed]) if reversal_transaction.save
    end
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Private methods
  #----------------------------------------------------------------------

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_site_entry_id",          type: "int(11)",          default: "NULL"},
                        { name:   "event_id",                     type: "varchar(255)",     default: "''"},
                        { name:   "type",                         type: "varchar(255)",     default: "'Single Event'"},
                        { name:   "amount",                       type: "float",            default: 0},
                        { name:   "tax_rate",                     type: "float",            default: 0},
                        { name:   "holdback_rate",                type: "float",            default: 0},
                        { name:   "advance",                      type: "float",            default: 0},
                        { name:   "event_cap",                    type: "int(11)",          default: "NULL"},
                        { name:   "event_count",                  type: "int(11)",          default: 0},
                        { name:   "start_date",                   type: "datetime",         default: "NULL"},
                        { name:   "end_date",                     type: "datetime",         default: "NULL"},
                        { name:   "status",                       type: "varchar(255)",     default: "'Editable'"},
                        { name:   "username",                     type: "varchar(255)",     default: "''" },
                        { name:   "email",                        type: "varchar(255)",     default: "''" },
                        { name:   "mysql_vpd_ledger_category_id", type: "int(11)",          default: "NULL"},
                        { name:   "mysql_site_id",                type: "int(11)",          default: "NULL"},
                        { name:   "created_at",                   type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",                   type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "site_entries"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>SiteEntry Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    status_label = STATUS.map do |k, v|
      k.to_s.camelize
    end

    query_count=0 and queries=""
    data = SiteEntry.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_site_entry_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "username"
            value_query += item.user.nil? || item.user.first_name.nil? ? "'', " : "\"#{item.user.first_name} #{item.user.last_name}\", "
            update_query += item.user.nil? || item.user.last_name.nil? ? "'', " : "\"#{item.user.first_name} #{item.user.last_name}\", "
          elsif field[:name] == "email"
            value_query += item.user.nil? || item.user.email.nil? ? "'', " : "\"#{item.user.email.to_s.gsub('"', '')}\", "
            update_query += item.user.nil? || item.user.email.nil? ? "'', " : "\"#{item.user.email.to_s.gsub('"', '')}\", "
          elsif field[:name] == "type"
            value_query += item[field[:name]].present? ? "\"#{VpdEvent::TYPE_LABEL[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{VpdEvent::TYPE_LABEL[item[field[:name]]]}\", " : "'', "
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
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_site_entry_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_site_entry_id`=#{item.id};").first
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
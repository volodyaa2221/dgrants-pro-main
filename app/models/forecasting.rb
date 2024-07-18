class Forecasting < ActiveRecord::Base

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :trial
  belongs_to  :vpd_country
  belongs_to  :vpd

  # Validations
  #----------------------------------------------------------------------
  validates_uniqueness_of :vpd_country_id, scope: :trial_id

  # Callbacks
  #----------------------------------------------------------------------
  after_save :set_trial_should_forecast
  after_update :sync_for_update

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Set country name by vpd_country
  def vpd_country=(val)
    self[:country_name] = vpd_country.name
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Public: Get all sites of this country in the given trial

  # Private methods
  #----------------------------------------------------------------------
  private
  # Private: Set trial as forecastable
  def set_trial_should_forecast
    if (est_start_date_changed? || recruitment_rate_changed?) && trial.forecastable? && !trial.should_forecast
      trial.update_attributes(should_forecast: true)
    end
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_forecasting_id",     type: "int(11)",          default: "NULL"},
                        { name:   "est_start_date",           type: "datetime",         default: "NULL"},
                        { name:   "recruitment_rate",         type: "float",            default: 0},
                        { name:   "mysql_trial_id",           type: "int(11)",          default: "NULL"},
                        { name:   "mysql_vpd_country_id",     type: "int(11)",          default: "NULL"},
                        { name:   "created_at",               type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",               type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "forecastings"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Forecasting Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = Forecasting.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_forecasting_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_forecasting_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_forecasting_id`=#{item.id};").first
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
class SiteSchedule < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  PAYMENT_TERM = [30, 45, 60, 90, 120]
  MODE = ["Payable", "Editable"]

  # Associations
  #----------------------------------------------------------------------
  belongs_to :currency
  belongs_to :vpd
  belongs_to :vpd_currency
  belongs_to :trial_schedule
  belongs_to :site

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :vpd_currency
  validates_uniqueness_of :site_id

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_schedules, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  # after_create :setup_schedule
  after_save :make_transactions
  after_update :sync_for_update

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Attribute methods
  #----------------------------------------------------------------------
  # Checks it has site_entries or site_passthrough_budget with payable status
  def ever_activated?
    budgets = SitePassthroughBudget.where("site_id = #{site.id} AND status != #{SiteEntry::STATUS[:editable]}").count
    activated = budgets > 0
    unless activated
      entries = SiteEntry.where("site_id = #{site.id} AND status != #{SiteEntry::STATUS[:editable]}").count
      activated = entries > 0
    end
    activated
  end

  # Checks if the site schedule has no entries or budgets entered at all
  def empty_entries?
    budgets = SitePassthroughBudget.where(site: site).count
    empty = budgets == 0
    if empty
      entries = SiteEntry.where(site: site).count
      empty = entries == 0
    end
    empty
  end

  # Returns 0: no PS entered at all, 1: some PS complete (but not approved), 2: if PS is in payable mode
  def schedule_status
    return 0 if empty_entries?
    return 2 if !mode && ever_activated?
    1
  end

  # Copy site entries and passthrough budgets from other site
  def copy_entries_from_site(schedule_site)
    schedule_site.site_entries.activated_entries.each do |entry|
      site.site_entries.create(event_id: entry.event_id, type: entry.type, amount: entry.amount, tax_rate: entry.tax_rate, holdback_rate: entry.holdback_rate, 
                              advance: entry.advance, event_cap: entry.event_cap, start_date: entry.start_date, end_date: entry.end_date, 
                              user: entry.user, vpd: self.vpd, vpd_ledger_category: entry.vpd_ledger_category)
    end
    schedule_site.site_passthrough_budgets.activated_budgets.each do |budget|
      site.site_passthrough_budgets.create(name: budget.name, max_amount: budget.max_amount, monthly_amount: budget.monthly_amount, vpd: self.vpd)
    end    
  end
  handle_asynchronously :copy_entries_from_site, priority: 9, run_at: Proc.new {1.second.from_now}

  # Private methods
  #----------------------------------------------------------------------
  private
  
  # Callbacks methods
  #----------------------------------------------------------------------
  def setup_schedule
    if trial_schedule.present?
      TrialEntry.where(trial_schedule: trial_schedule).each do |entry|
        site.site_entries.create(event_id: entry.event_id, type: entry.type, amount: entry.amount, tax_rate: entry.tax_rate, holdback_rate: entry.holdback_rate, 
                                advance: entry.advance, event_cap: entry.event_cap, start_date: entry.start_date, end_date: entry.end_date, 
                                user: entry.user, vpd: self.vpd, vpd_ledger_category: entry.vpd_ledger_category)
      end
      TrialPassthroughBudget.where(trial_schedule: trial_schedule).each do |budget|
        site.site_passthrough_budgets.create(name: budget.name, max_amount: budget.max_amount, monthly_amount: budget.monthly_amount, vpd: self.vpd)
      end
    end
  end
  handle_asynchronously :setup_schedule, priority: 9, run_at: Proc.new {1.second.from_now}

  def make_transactions
    if self.mode_changed? && !self.mode
      rate = currency.rate
      related_site_ids = site.related_site_ids
      SiteEntry.where("site_id = #{site.id} AND status != #{SiteEntry::STATUS[:disabled]}").each do |entry|
        SiteEvent.where("site_id IN (#{related_site_ids.join(",")}) AND event_id = '#{entry.event_id}' AND type = #{entry.type} AND status = 1 AND happened_at >= '#{entry.start_date}' AND happened_at <= '#{entry.end_date}'").each do |event|
          need_create = entry.status == SiteEntry::STATUS[:editable]  ?  true : !Transaction.where(site: site, site_entry: entry, site_event: event).exists?
          if need_create
            amount = entry.amount.to_f
            tax_rate = entry.tax_rate.to_f
            holdback_rate = entry.holdback_rate.to_f
            retained_amount = amount * holdback_rate/100.0
            tax = amount * tax_rate/100.0
            retained_tax = tax * holdback_rate/100.0
            earned = amount + tax
            retained = retained_amount + retained_tax
            entry.transactions.create(type: event.type, type_id: event.event_id, patient_id: event.patient_id, happened_at: event.happened_at,
                                      amount: amount, tax: tax, retained_amount: retained_amount, retained_tax: retained_tax,
                                      earned: earned, retained: retained, advance: entry.advance, usd_rate: rate, source: event.source, 
                                      vpd: entry.vpd, site: site, site_event: event)
          end
        end
        entry.update_attributes(status: SiteEntry::STATUS[:payable]) unless entry.status == SiteEntry::STATUS[:payable]
      end

      SitePassthroughBudget.where("site_id = #{site.id} AND status != #{SitePassthroughBudget::STATUS[:disabled]}").each do |budget|
        Passthrough.where(site: site, site_passthrough_budget: budget, status: Passthrough::STATUS[:approved]).each do |passthrough|
          need_create = budget.status == SitePassthroughBudget::STATUS[:editable]  ?  true : !Transaction.where(site: site, site_passthrough_budget: budget, passthrough: passthrough).exists?
          if need_create
            budget.transactions.create(type: Transaction::TYPE[:passthrough], type_id: budget.name, happened_at: passthrough.happened_at,
                                      amount: passthrough.amount, earned: passthrough.amount, usd_rate: rate, 
                                      vpd: budget.vpd, site: site, passthrough: passthrough)
          end
        end
        budget.update_attributes(status: SitePassthroughBudget::STATUS[:payable]) unless budget.status == 1
      end
    end
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_site_schedule_id",     type: "int(11)",          default: "NULL"},
                        { name:   "mode",                       type: "varchar(255)",     default: "'Editable'"},
                        { name:   "tax_rate",                   type: "float",            default: 0},
                        { name:   "withholding_rate",           type: "float",            default: 0},
                        { name:   "overhead_rate",              type: "float",            default: 0},
                        { name:   "holdback_rate",              type: "float",            default: 0},
                        { name:   "holdback_amount",            type: "float",            default: "NULL"},
                        { name:   "payment_terms",              type: "int(11)",          default: 30},
                        { name:   "status",                     type: "varchar(255)",     default: "NULL"},
                        { name:   "mysql_vpd_currency_id",      type: "int(11)",          default: "NULL"},
                        { name:   "mysql_trial_schedule_id",    type: "int(11)",          default: "NULL"},
                        { name:   "mysql_site_id",              type: "int(11)",          default: "NULL"},
                        { name:   "created_at",                 type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",                 type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "site_schedules"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>SiteSchedule Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = SiteSchedule.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_site_schedule_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "mode"
            value_query += !item[field[:name]].nil? ? "\"#{MODE[item[field[:name]] ? 1 : 0]}\", " : "'', "
            update_query += !item[field[:name]].nil? ? "\"#{MODE[item[field[:name]] ? 1 : 0]}\", " : "'', "
          elsif field[:name] == "status"
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
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_site_schedule_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_site_schedule_id`=#{item.id};").first
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
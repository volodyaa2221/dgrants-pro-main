class SiteEvent < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Constants
  #----------------------------------------------------------------------
  SOURCE = {manual: "Manual", api: "API", forecasting: "Forecasting"}
  STATUS = ["Deleted", "Verified"]

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :vpd
  belongs_to  :site

  has_many    :transactions, dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :event_id, :type, :happened_at, :happened_at_text, :source, :author
  validates_presence_of :patient_id, {if: Proc.new{|site_event| site_event.type == VpdEvent::TYPE[:patient_event]}}
  validate :check_uniquness_of_event_log_id, :check_order
  # validates_uniqueness_of :event_id, {if: Proc.new{|site_event| site_event.type == VpdEvent::TYPE[:single_event]},  scope: :site_id}
  # validates_uniqueness_of :event_id, {if: Proc.new{|site_event| site_event.type == VpdEvent::TYPE[:patient_event]}, scope: [:site_id, :patient_id]}
  
  # Scopes
  #----------------------------------------------------------------------
  scope :activated_events,    -> {where(status: 1)}     # Verifed events
  scope :forecasting_events,  -> {where(source: SOURCE[:forecasting])}
  scope :real_events,         -> {where("source != '#{SOURCE[:forecasting]}'")}

  # Callbacks
  #----------------------------------------------------------------------
  after_create  :after_create_event
  after_update  :after_update_event, :sync_for_update
  after_destroy :after_destroy_event

  # Validation methods
  #----------------------------------------------------------------------
  # Public: Check if event log with same event log id is aready logged
  def check_uniquness_of_event_log_id
    if event_id == "CONSENT"  &&  self.new_record?
      trial = site.trial
      patients_count = (source == SOURCE[:forecasting]) ? trial.patients_count : trial.real_patients_count
      if trial.max_patients.present?  &&  patients_count >= trial.max_patients.to_i
          errors.add(:patient_id, "can't be added anymore")
          return
      end
      if source != SOURCE[:forecasting]  &&  description.blank?
        errors.add(:description, "can't be blank")
        return
      end
    end
    site_events = duplicated_site_events_by_event_log_id(false)
    errors.add(:event_log_id, "is already logged") if site_events.exists?
  end

  # Public: Check if event order is right or wrong
  def check_order
    return unless self.new_record? || source != SOURCE[:forecasting] || event_id != "CONTRACT" || event_id != "CONSENT"
    trial_event = TrialEvent.where(trial: site.trial, type: type, status: 1, event_id: event_id).first
    trial_events = TrialEvent.where("trial_id = #{site.trial.id} AND type = #{type} AND status = 1 AND event_id NOT IN ('CONTRACT', 'CONSENT', '#{event_id}') AND days < #{trial_event.days}").map {|e| "'#{e.event_id}'"}

    if trial_events.present?
      related_site_ids = site.related_site_ids
      where_case = "site_id IN (#{related_site_ids.join(",")}) AND event_id IN (#{trial_events.join(",")}) AND happened_at > '#{happened_at}' AND status = 1"
      if type == VpdEvent::TYPE[:single_event]
        trial_events << "CONTRACT"
        site_events = SiteEvent.where(where_case) if related_site_ids.present?
      else
        trial_events << "CONSENT"
        site_events = SiteEvent.where("#{where_case} AND patient_id = #{patient_id}") if related_site_ids.present?
      end
    end

    if site_events.present? && site_events.exists?
      errors.add(:happened_at, "can't be ahead of prior events")
    end
  end

  # Public: Used to check CONSENT logged with a patient_id before logging any patient events
  def self.check_pt_start_by_patient_id(site_id, patient_id)
    where("site_id = #{site_id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND event_id = 'CONSENT' AND patient_id = '#{patient_id}' AND status = 1").count > 0
  end

  # Attribute methods
  #----------------------------------------------------------------------
  # Public: Get type label for type
  def type_label
    VpdEvent::TYPE_LABEL[self.type]
  end

  # Public: Get event_id label
  def event_id_label
    (self.type == VpdEvent::TYPE[:single_event]) ? self.event_id : "#{self.event_id}+#{self.patient_id}"
  end

  # Public: Get status label
  def status_label
    self.status==0 ? "Unverified" : "Verified"
  end

  # Public: Disable transactions(create reversal transactions)
  def disable_transactions
    related_site_ids = site.related_site_ids
    if related_site_ids.present?
      old_transactions = Transaction.where("site_id IN (#{related_site_ids.join(",")}) AND site_event_id = #{self.id} AND status = #{Transaction::STATUS[:normal]}").map{|transaction| transaction}
      old_transactions.each do |t|
        earned = t.amount + t.tax
        retained = t.retained_amount + t.retained_tax      
        reversal_transaction = self.transactions.build(type: t.type, type_id: t.type_id, patient_id: t.patient_id, happened_at: t.happened_at, payable: t.payable,
                                                       amount: -1*t.amount, tax: -1*t.tax, retained_amount: -1*t.retained_amount, retained_tax: -1*t.retained_tax, 
                                                       earned: -1*earned, retained: -1*retained, advance: -1*t.advance, usd_rate: t.usd_rate, source: t.source, status: Transaction::STATUS[:disabled], 
                                                       vpd: self.vpd, site: t.site, site_entry: t.site_entry)
        t.update_attributes(status: Transaction::STATUS[:reversed]) if reversal_transaction.save
      end
    end
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Public: Gets all available patient_ids for a site
  def self.logged_patient_ids(site)
    where(site: site, type: VpdEvent::TYPE[:patient_event], event_id: "CONSENT", status: 1).map(&:patient_id)
  end

  # Public: Get duplicated site event logs by event_log_id(if forecasting is false, it's validation call nor setup call)
  def duplicated_site_events_by_event_log_id(forecasting=false)
    site_events = nil
    related_site_ids = site.related_site_ids
    site_events = SiteEvent.where(site_id: related_site_ids, event_log_id: event_log_id, status: 1)

    if source != SOURCE[:forecasting]  &&  !forecasting
      site_events = site_events.real_events
    end

    return self.id.nil? ? site_events : site_events.where("id != #{self.id}")
  end

  # Callback methods
  #----------------------------------------------------------------------
  # Public: Do some after processes when new event log is logged
  def after_create_event
    trial = self.site.trial.reload
    trial_event = TrialEvent.where(trial_id: trial.id, event_id: self.event_id).first
    trial_event.update_attributes(editable: false) unless !trial_event.editable

    unless self.source == SOURCE[:forecasting]
      site_events = duplicated_site_events_by_event_log_id(true)
      if site_events.exists?
        site_events.destroy_all
      end
    end

    if approved
      related_site_ids = site.related_site_ids
      SiteSchedule.where(site_id: related_site_ids, status: 1, mode: false).each do |schedule|
        related_site  = schedule.site 
        rate          = schedule.currency.rate
        SiteEntry.where("site_id = #{related_site.id} AND event_id = '#{event_id}' AND type = #{type} AND status = #{SiteEntry::STATUS[:payable]} AND start_date <= '#{happened_at}' AND end_date >= '#{happened_at}'").each do |entry|
          amount = entry.amount.to_f
          tax_rate = entry.tax_rate.to_f
          holdback_rate = entry.holdback_rate.to_f
          retained_amount = amount * holdback_rate/100.0
          tax = amount * tax_rate/100.0
          retained_tax = tax * holdback_rate/100.0
          earned = amount + tax
          retained = retained_amount + retained_tax
          entry.transactions.create(type: type, type_id: event_id, patient_id: patient_id, happened_at: happened_at,
                                    amount: amount, tax: tax, retained_amount: retained_amount, retained_tax: retained_tax,
                                    earned: earned, retained: retained, advance: entry.advance, usd_rate: rate, source: source, 
                                    vpd: self.vpd, site: related_site, site_event: self, included: 0)
        end
      end

      setup_site_event(true)
    end
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  # Private: Do some after processes when event log is changed
  def after_update_event
    return unless self.status_changed?

    setup_site_event(false)
  end

  # Private: Reduce Trial's max_patients and delete Site's start date when CONTRACT event log is deleted
  def after_destroy_event
    setup_site_event(false) if status == 1
  end

  # Private: Do some after processes when new event log is logged(if creative=true, after_create call nor after_update/after_destroy call)
  def setup_site_event(creative=false)
    start_date = site.start_date
    if creative
      if start_date.nil? || (start_date.present? && happened_at<start_date)
        site.update_attributes(start_date: happened_at)
      end
    else
      events = SiteEvent.where("site_id = #{site.id} AND source != '#{SOURCE[:forecasting]}' AND status = 1 AND id != #{id}").order(happened_at: :asc)
      if events.exists?
        site.update_attributes(start_date: events.first.happened_at)
      else
        site.update_attributes(start_date: nil)
      end
    end

    trial = site.trial.reload
    if event_id == "CONTRACT"
      unless source == SOURCE[:forecasting] || !trial.forecastable?
        trial.update_attributes(should_forecast: true)
      end
    elsif event_id == "CONSENT"
      x = creative ? 1 : -1
      real_patients_count = (source == SOURCE[:forecasting]) ? trial.real_patients_count : trial.real_patients_count + x
      real_patients_count = 0 if real_patients_count < 0
      patients_count      = trial.patients_count + x
      patients_count      = 0 if patients_count < 0
      should_forecast     = false
      if trial.forecastable?
        should_forecast   = (source == SOURCE[:forecasting]) ? patients_count < trial.max_patients.to_i : true
      end
      trial.update_attributes(real_patients_count: real_patients_count, patients_count: patients_count, should_forecast: should_forecast)
    # else # Other event logs
    #   # trial.partial_forecast(site, event_id, patient_id) unless (creative || source == SOURCES[:forecasting])
    end
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_site_event_id",          type: "int(11)",          default: "NULL"},
                        { name:   "event_id",                     type: "varchar(255)",     default: "''"},
                        { name:   "type",                         type: "varchar(255)",     default: "'Single Event'"},
                        { name:   "description",                  type: "varchar(255)",     default: "''"},
                        { name:   "patient_id",                   type: "varchar(255)",     default: "NULL"},
                        { name:   "happened_at",                  type: "datetime",         default: "NULL"},
                        { name:   "happened_at_text",             type: "varchar(255)",     default: "NULL"},
                        { name:   "source",                       type: "varchar(255)",     default: "'Manual'"},
                        { name:   "author",                       type: "varchar(255)",     default: "NULL"},
                        { name:   "co_author",                    type: "varchar(255)",     default: "NULL"},
                        { name:   "status",                       type: "varchar(255)",     default: "NULL"},
                        { name:   "mysql_site_id",                type: "int(11)",          default: "NULL" },
                        { name:   "created_at",                   type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",                   type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "site_events"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>SiteEvent Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = SiteEvent.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_site_event_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "type"
            value_query += item[field[:name]].present? ? "\"#{VpdEvent::TYPE_LABEL[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{VpdEvent::TYPE_LABEL[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "status"
            value_query += item[field[:name]].present? ? "\"#{STATUS[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{STATUS[item[field[:name]]]}\", " : "'', "
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_site_event_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_site_event_id`=#{item.id};").first
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
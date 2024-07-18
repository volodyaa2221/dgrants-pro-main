class Site < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  TYPE = %w[University\ Hospital General\ Hospital Medical\ Clinic SMO/Research\ Only]
  PAYMENT_VERIFIED = {empty: 0, known_bad: 1, presumed_good: 2, known_good: 3}

  # Payment Schedule Status
  #     empty:          no PS entered at all 
  #     some_complete:  some PS complete (but not approved)
  #     in_payable:     PS is in payable mode
  PAYMENT_SCHEDULE_SATUS = {empty: 0, some_complete: 1, in_payable: 2}

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :vpd
  belongs_to  :country
  belongs_to  :vpd_country
  belongs_to  :trial

  has_many    :roles, as: :rolify,        dependent: :destroy    
  has_many    :site_events,               dependent: :destroy
  has_one     :site_schedule,             dependent: :destroy
  has_many    :site_entries,              dependent: :destroy
  has_many    :transactions,              dependent: :destroy
  has_many    :invoices
  has_many    :site_passthrough_budgets,  dependent: :destroy
  has_many    :passthroughs,              dependent: :destroy
  has_one     :payment_info,              dependent: :destroy

  belongs_to  :main_site, class_name: "Site"
  has_many    :subsites,  class_name: "Site", foreign_key: "main_site_id"

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :name, :site_id, :trial_id
  validates_uniqueness_of :site_id, scope: :trial_id, case_sensitive: false

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_sites,       -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_update :after_update_site, :sync_for_update
  after_save   :setup_site

  # Flag methods
  #----------------------------------------------------------------------
  # Public: Check this site has valid real event log
  def trial_associate?(user)
    Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:trial_associate]).exists?
  end
  
  # Public: Check if the given user is real site admin in this site
  def site_admin?(user)
    Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:site_admin]).exists?
  end

  # Public: Check if the given user is real site user in this site
  def site_user?(user)
    Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:site_user]).exists?
  end

  # Public: Check if the given user is real site readonly user in this site
  def site_readonly?(user)
    Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:site_readonly]).exists?
  end

  # Public: Check if the given user is real site user(SA, SU, SAR) in this site
  def site_only_user?(user)
    role = Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user)
    if role.exists?
      role.first.role >= Role::ROLE[:site_admin]
    else
      false
    end
  end

  # Public: Check if the given user is SA/SU/Monitor in this site
  def site_admin_user_monitor?(user)
    roles = [Role::ROLE[:site_admin], Role::ROLE[:site_user], Role::ROLE[:trial_associate]]
    Role.where(rolify_type: Site, rolify_id: self.id, status: 1, user: user, role: roles).exists?
  end

  # Public: Determines if site has events which require TA/Monitor approval
  def has_pending_events?
    site_events.where(status: 1, approved: false).count > 0
  end

  # Invoice & Transactions methods
  #----------------------------------------------------------------------
  # Public: Gets past invoices amount, a specific invoice amount, total balance
  def invoice_amounts(invoice, transaction_ids=nil)
    past = Transaction.past_invoices_amounts(self, invoice)
    amounts = Transaction.invoice_amounts(self, invoice, transaction_ids)
    balance = amounts[:amount] + past[:earned] - past[:retained] - past[:remitted]
    return past, amounts, balance
  end

  # Public: Gets transactions of current invoice of the site
  def current_transactions
    transactions.where("source != '#{SiteEvent::SOURCE[:forecasting]}' AND payable = true AND invoice_id IS NULL AND included != 0")
  end

  # Public: Gets last invoice of the site
  def last_invoice
    invoices.order(:created_at).last
  end

  # Public: Checks the current invoice due for submission
  def current_invoice_overdue_for_submission?(base_time = nil)
    base_time = Time.now if base_time.nil?
    result = false
    if current_transactions.count > 0
      last_time = current_transactions.order(:created_at).first.created_at
      result = (base_time - last_time).to_i.abs/86400 > 30
    end
    result
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Get all activated users of this site
  def users(include_disabled=false)
    users = include_disabled ? roles.map(&:user) : Role.where(rolify_type: Site, rolify_id: self.id, status: 1).map(&:user)
    users.map{|user| user if user.status==1}
  end

  # Public: Get all activated site admins of this site
  def site_admins(include_disabled=false)
    users = include_disabled ? Role.where(rolify_type: Site, rolify_id: self.id, role: Role::ROLE[:site_admin]).map(&:user) : 
                              Role.where(rolify_type: Site, rolify_id: self.id, status: 1, role: Role::ROLE[:site_admin]).map(&:user)
    users.map{|user| user if user.status==1}
  end

  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Attributes methods
  #----------------------------------------------------------------------
  # Public: Get full PI name
  def pi_name
    [pi_first_name, pi_last_name].join(" ").strip
  end

  # Public: Set site Id as CAPs
  def site_id=(val)
    self[:site_id] = val.upcase
  end

  # Public: Get Last Patient ID Number
  def last_patient_id_params(forecasting=true)
    if forecasting
      pt_start_events = SiteEvent.where(site: self, event_id: "CONSENT", status: 1).order(:happened_at => :asc)
    else 
      pt_start_events = SiteEvent.where("site_id = #{self.id} AND source != '#{SiteEvent::SOURCE[:forecasting]}' AND event_id = 'CONSENT' AND status = 1").order(:happened_at => :asc)
    end
    last_pt_start_event = pt_start_events.last if pt_start_events.exists?

    patient_id      = last_pt_start_event.present? ? last_pt_start_event.patient_id : "0"
    happened_at     = last_pt_start_event.present? ? last_pt_start_event.happened_at : nil
    patient_prefix  = patient_id.gsub(/\d+/, '').squeeze(' ').strip # Remove number letters
    patient_number  = patient_id.gsub(/[^\d]/, '').to_i             # Get only number letters
    {prefix: patient_prefix, number: patient_number, happened_at: happened_at}
  end

  # Public: Get all related sites(main site and sub sites)
  def related_site_ids
    if main_site.nil? && !subsites.exists? # single site
      [self.id]
    else # associated site(has main or sub sites)
      if main_site.present? # sub site
        Site.where(trial: trial, main_site: main_site, status: 1).map(&:id) << main_site.id
      else # main site
        Site.where(trial: trial, main_site: self, status: 1).map(&:id) << self.id
      end
    end
  end

  # Public: Generates a new event_log_id unique to this site
  def new_event_log_id
    max_id = site_events.where.not(source: SiteEvent::SOURCE[:forecasting]).maximum(:event_log_id).to_i + 1
    digits = max_id > 99999  ?  8 : 5
    max_id = max_id.to_s.rjust(digits, '0')
  end

  # Class methods
  #----------------------------------------------------------------------
  # Public: (Scheduler method) Checks sites with current invoice overdue and marks the flag
  def self.check_overdue_invoices
    site_ids = []
    base_time = Time.now
    all.each do |site|
      site_ids << site.id if site.current_invoice_overdue_for_submission?(base_time)
    end
    where(id: site_ids).update_all(is_invoice_overdue: 1) if site_ids.count > 0
  end


  private
  # Callbacks
  #----------------------------------------------------------------------
  # Private: Set site schedule as this site's status changed
  def after_update_site
    site_schedule.update_attributes(status: status) if self.status_changed?
  end

  # Private: Set trial as forecastable after saving
  def setup_site
    if (self.country_name_changed? || self.status_changed?) && self.trial.forecastable? && !self.trial.should_forecast
      self.trial.update_attributes(should_forecast: true)
    end
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_site_id",            type: "int(11)",          default: "NULL"},
                        { name:   "name",                     type: "varchar(255)",     default: "''"},
                        { name:   "site_id",                  type: "varchar(255)",     default: "''"},
                        { name:   "site_type",                type: "varchar(255)",     default: "NULL"},
                        { name:   "city",                     type: "varchar(255)",     default: "''"},
                        { name:   "state",                    type: "varchar(255)",     default: "NULL"},
                        { name:   "state_code",               type: "varchar(255)",     default: "''"},
                        { name:   "address",                  type: "varchar(255)",     default: "''"},
                        { name:   "zip_code",                 type: "varchar(255)",     default: "''"},
                        { name:   "country_name",             type: "varchar(255)",     default: "''"},
                        { name:   "start_date",               type: "datetime",         default: "NULL"},
                        { name:   "status",                   type: "varchar(255)",     default: "NULL"},
                        { name:   "payment_verified",         type: "varchar(255)",     default: "NULL"},
                        { name:   "mysql_vpd_country_id",     type: "int(11)",          default: "NULL"},
                        { name:   "mysql_trial_id",           type: "int(11)",          default: "NULL"},
                        { name:   "mysql_main_site_id",       type: "int(11)",          default: "NULL"},
                        { name:   "created_at",               type: "timestamp",        default: "NULL"},
                        { name:   "updated_at",               type: "timestamp",        default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "sites"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Site Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    payment_verified = PAYMENT_VERIFIED.map do |k, v|
      k.to_s.humanize.titleize
    end

    query_count=0 and queries=""
    data = Site.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
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
            if field[:name] == "mysql_site_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            else
              field_name    = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
              value_query  += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
              update_query += item[field_name].nil? ? "NULL, " : "#{item[field_name]}, "
            end
          elsif field[:name] == "site_type"
            value_query += item[field[:name]].present? ? "\"#{TYPE[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{TYPE[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "status"
            value_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "payment_verified"
            value_query += item[field[:name]].present? ? "\"#{payment_verified[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{payment_verified[item[field[:name]]]}\", " : "'', "
          else
            value_query  += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
            update_query += item[field[:name]].nil? ? "'', " : "\"#{item[field[:name]].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_site_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_site_id`=#{item.id};").first
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
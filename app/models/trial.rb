class Trial < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  INDICATIONS = ["Cardiovascular", "Dermatology", "Endocrinology", "Gastroenterology", "Hematology", "Infectious Diseases", "Musculoskeletal", "Nephrology", "Neurology", "Obstetrics", "Oncology", "Ophthalmology", "Otolaryngology", "Psychiatry", "Respiratory", "Urology"]
  PHASES      = ["Phase I", "Phase II", "Phase III", "Phase IV"]
  EVENT_LOG_MODE = ["Sites cannot manually log events", "Sites can log events which require approval", "Sites can log events which are automatically approved"]

  # Associations
  #----------------------------------------------------------------------
  belongs_to :sponsor
  belongs_to :vpd
  belongs_to :vpd_sponsor

  has_many :roles, as: :rolify, dependent: :destroy
  has_many :sites,              dependent: :destroy
  has_many :trial_events,       dependent: :destroy
  has_many :forecastings,       dependent: :destroy
  has_one  :account,            dependent: :destroy
  has_many :trial_schedules,    dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :trial_id, :vpd_id
  validates_uniqueness_of :trial_id, scope: :vpd_id, case_sensitive: false

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_trials, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_create :setup_trial
  after_save   :set_trial_forecastable
  after_update :sync_for_update

  # Class methods
  #----------------------------------------------------------------------
  # Public: Create forecasting event logs for all sites
  def self.forecast(trial=nil)
    p "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
    p "Starting forecasting..."
    if trial.present?
      trial.forecast
    else
      self.activated_trials.each do |trial|
        trial.forecast
      end
    end
    p "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
  end

  # Flag methods
  #----------------------------------------------------------------------
  # Public: Check if the given user is real trial admin in this trial
  def trial_admin?(user)
    Role.where(rolify_type: Trial, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:trial_admin]).exists?
  end

  # Public: Check if the given user is real trial read only or not in this trial
  def trial_readonly?(user)
    Role.where(rolify_type: Trial, rolify_id: self.id, status: 1, user: user, role: Role::ROLE[:trial_readonly]).exists?
  end

  # Public: Get role name of given user
  def role_name_by_user(user)
    if user.super_admin?
      "<p title='Super Admin'>A</p>"
    elsif user.vpd_admin?(self)
      "<p title='VPD Admin'>A</p>"
    elsif trial_admin?(user)
      "<p title='Trial Admim'>A</p>"
    elsif trial_readonly?(user)
      "<p title='Trial Admin Read-Only'>A</p>"
    else
      role = user.trial_role(self)
      if role.present?
        role_label = role.role_label
        "<p title='#{role_label[0]}'>#{role_label[1]}</p>"
      else
        role = nil
        Site.where(trial: self, status: 1).each do |site|
          temp = user.site_role(site)
          if temp.present?  &&  (role.nil?  ||  temp.role<role.role)
            role = temp
          end
        end
        if role.present?
          role_label = role.role_label
          "<p title='#{role_label[0]}'>#{role_label[1]}</p>"
        else
          "Disabled"
        end
      end
    end
  end

  # Public: Check if this trial is forecastable or not
  def forecastable?
    self.max_patients.present?
  end

  # Collection methods
  #----------------------------------------------------------------------  
  # Public: Get all trial admin users of this trial
  def trial_admins(include_disabled=false)
    users = include_disabled ? roles.map(&:user) : Role.where(rolify_type: Trial, rolify_id: self.id, status: 1).map(&:user)
    users.map{|user| user if user.status==1}
  end

  # Public: Get all site users of this trial
  def site_users(include_disabled=false)
    users = []
    Site.where(trial: self, status: 1).each do |site|
      if include_disabled
        temp = site.roles.map(&:user)
        users << temp.map{|user| user if user.status==1}
      else 
        temp = Role.where(rolify_type: Site, rolify_id: site.id, status: 1).map(&:user)
        users << temp.map{|user| user if user.status==1}
      end
    end
    users.flatten
  end

  # Public: Get all VPD Countries of this trial
  def vpd_countries(include_disabled=false)
    country_ids = Site.where(trial: self, status: 1).map(&:vpd_country_id).compact.uniq
    include_disabled ? VpdCountry.where(id: country_ids) : VpdCountry.where(id: country_ids, status: 1)
  end

  # Public: Get all VPD Currencies of this trial
  def vpd_currencies(include_disabled=false)
    include_disabled ? VpdCurrency.where(vpd_id: self.vpd_id, status: 1) : VpdCurrency.where(vpd_id: self.vpd_id)
  end

  # Public: Get all sites with given VPD Country
  def sites_for_vpd_country(vpd_country_id)
    if vpd_country_id == "all_countries"
      Site.where(trial: self, status: 1)
    else
      Site.where(trial: self, vpd_country_id: vpd_country_id, status: 1)
    end
  end

  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Finds all sites having schedules with a vpd_currency of this trial
  def sites_having_schedules_by_currency(vpd_currency_id)
    join_clause  = "LEFT JOIN site_schedules ss ON ss.site_id = s.id"
    where_clause = "s.trial_id = #{id} AND ss.vpd_currency_id = #{vpd_currency_id} AND s.status = 1"
    Site.select("s.*").from("sites s").joins(join_clause).where(where_clause)
  end

  # Attributes methods
  #----------------------------------------------------------------------
  # Public: Get CONTRACT Trial Event with given type
  def start_event(type)
    event_id = type==VpdEvent::TYPE[:single_event] ? "CONTRACT" : "CONSENT"
    TrialEvent.where(trial: self, event_id: event_id, type: type).first
  end

  # Public: Get earlist Site start date
  def start_date
    dates = Site.where(trial: self, status: 1).order(start_date: :asc).map(&:start_date).compact
    if dates.count > 0  &&  dates.first.present?
      return dates.first
    else
      return Time.now.to_date
    end
  end

  # Public: Get End Date(last site event log date)
  def end_date
    site_ids    = Site.where(trial: self, status: 1).map(&:id)
    site_events = SiteEvent.where(site_id: site_ids, status: 1).order(happened_at: :asc)
    site_event  = site_events.last if site_events.exists?
    if site_event.present?
      return site_event.happened_at
    else
      return Time.now.to_date
    end
  end

  # Public: Get Sponsor Name
  def sponsor_name
    sponsor.present? ? sponsor.name : ''
  end

  STATUS = %w(Disabled Acitve)
  # Public: Get status label of this trial
  def status_label
    STATUS[status]
  end

  # Public: Set trial Id as CAPs
  def trial_id=(val)
    self[:trial_id] = val.upcase
  end

  # Callback methods
  #----------------------------------------------------------------------
  # Public: Copy all activated VPD Events after this trial is created
  def setup_trial
    vpd_events = VpdEvent.where(vpd_id: self.vpd_id, status: 1).order(created_at: :asc)
    vpd_events.each do |vpd_event|
      event_id    = vpd_event.event_id
      type        = vpd_event.type
      description = vpd_event.description
      days        = vpd_event.days
      order       = vpd_event.order
      if vpd_event.dependency.present?
        dependency = TrialEvent.where(trial_id: self.id, vpd_event_id: vpd_event.dependency_id).first
      else 
        dependency = nil
      end

      trial_event = self.trial_events.build(event_id: event_id, type: type, description: description, days: days, order: order, dependency: dependency, vpd: self.vpd, vpd_event: vpd_event)
      trial_event.save
    end
  end

  # Public: Reset should_forecast field after this trial is saved
  def set_trial_forecastable
    if self.max_patients_changed? || self.status_changed?
      if self.forecastable?  &&  self.status == 1
        self.update_attributes(should_forecast: true) unless self.should_forecast
      else
        self.update_attributes(should_forecast: false) if self.should_forecast
        site_ids = Site.where(trial: self, status: 1).map(&:id)
        SiteEvent.where(site_id: site_ids, source: SiteEvent::SOURCE[:forecasting]).destroy_all
      end
    end
  end

  # Action methods
  #----------------------------------------------------------------------
  # Public: Create partial forecasting event logs for a special event_id
  def partial_forecast(site, event_id, patient_id=nil)
    trial_events = TrialEvent.where(trial_id: self.id, event_id: event_id)
    if patient_id.present? # Patient Event
      create_patient_site_event_log_for_existing(trial_events, site)
    else # Single Event
      create_single_site_event_log(trial_events.first, site, site.start_date)
    end
  end

  # Public: Create forecasting event logs for all sites
  def forecast
    p "Trail : #{self.trial_id}"
    if !self.forecastable? || !self.should_forecast
      p "    #{self.trial_id} can't be forecasted" 
      self.update_attributes(should_forecast: false)
      return
    end

    self.update_attributes(forecasting_now: true)

    p "    Deleting all forecasting site event logs..."
    site_ids = Site.where(trial: self, status: 1).map(&:id)
    SiteEvent.where(site_id: site_ids, source: SiteEvent::SOURCE[:forecasting]).destroy_all if site_ids.present?
    self.update_attributes(patients_count: real_patients_count)

    trial_single_events   = TrialEvent.where(trial: self, type: VpdEvent::TYPE[:single_event], status: 1).order(type: :asc, dependency_id: :asc, days: :asc, created_at: :asc)
    trial_patient_events  = TrialEvent.where(trial: self, type: VpdEvent::TYPE[:patient_event], status: 1).order(type: :asc, dependency_id: :asc, days: :asc, created_at: :asc)
    pt_start_events = []

    Site.where(trial: self, status: 1).each do |site|
      p "    Site : #{site.site_id}"
      start_date  = site.start_date
      forecasting = Forecasting.where(trial: self, vpd_country_id: site.vpd_country_id)
      next if !forecasting.exists? && start_date.nil?
      forecasting = forecasting.first if forecasting.exists?
      start_date  = forecasting.est_start_date if start_date.nil? && forecasting.present?

      trial_single_events.each do |trial_event|
        site_events = SiteEvent.where(site: site, event_id: trial_event.event_id, status: 1).count
        create_single_site_event_log(trial_event, site, start_date) unless site_events > 0          
      end

      create_patient_site_event_log_for_existing(trial_patient_events, site)

      if forecasting.present? && forecasting.recruitment_rate>0
        pt_start_events << next_pt_start(site, start_date, forecasting.recruitment_rate)
      end      
    end

    p "    Creating Patient Event Logs"
    while self.reload.should_forecast  &&  pt_start_events.count > 0
      pt_start_events.sort_by!{|pt_start_event| pt_start_event[:happened_at]}
      
      pt_start_event = pt_start_events.shift
      create_patient_site_event_log(trial_patient_events, pt_start_event[:site], pt_start_event[:patient_id], pt_start_event[:happened_at])
      pt_start_events << next_pt_start(pt_start_event[:site], pt_start_event[:happened_at], pt_start_event[:recruitment_rate])     
    end

    self.update_attributes(forecasting_now: false, should_forecast: false)
    p "    Trail : #{self.trial_id}, forecasted!!!"
  end
  handle_asynchronously :forecast, priority: 10, run_at: Proc.new {1.second.from_now}

  # Private methods
  #----------------------------------------------------------------------
  private
  # Private: Create forecasting patient site event logs for existing CONSENT events
  def create_patient_site_event_log_for_existing(trial_events, site)
    pt_start_events = SiteEvent.where(site: site, event_id: "CONSENT", status: 1).order(:happened_at => :asc)
    pt_start_events.each do |pt_start_event|
      patient_id = pt_start_event.patient_id
      trial_events.each do |trial_event|
        next if trial_event.event_id == "CONSENT"
        site_events = SiteEvent.where(site: site, event_id: trial_event.event_id, patient_id: patient_id, status: 1)
        next if site_events.exists?
        days = trial_event.days.present? ? trial_event.days : 0
        happened_at = pt_start_event.happened_at + days.days
        create_site_event_log(trial_event, site, patient_id, happened_at)
      end
    end
  end

  # Private: Get next CONSENT event log date
  def next_pt_start(site, start_date, recruitment_rate)
    pt_start_event_params = site.last_patient_id_params(true)

    patient_number  = pt_start_event_params[:number] + 1
    happened_at     = pt_start_event_params[:happened_at].present? ? pt_start_event_params[:happened_at] : start_date

    patient_id      = patient_number.to_s.rjust(4, '0')
    happened_at     = happened_at + (1/recruitment_rate*30).days
    {site: site, happened_at: happened_at, patient_id: patient_id, recruitment_rate: recruitment_rate}
  end

  # Private: Create forecasting single site event logs 
  def create_single_site_event_log(trial_event, site, start_date)
    if trial_event.dependency.nil?
      create_site_event_log(trial_event, site, nil, start_date)
    else
      days = trial_event.days.present? ? trial_event.days : 0
      happened_at = start_date + days.days
      create_site_event_log(trial_event, site, nil, happened_at) 
    end
  end

  # Private: Create forecasting patient site event log
  def create_patient_site_event_log(trial_events, site, patient_id, pt_start_happened_at)
    create_site_event_log(trial_events.where(event_id: "CONSENT").first, site, patient_id, pt_start_happened_at)
    trial_events.each do |trial_event|
      next if trial_event.event_id == "CONSENT"
      days = trial_event.days.present? ? trial_event.days : 0
      happened_at = pt_start_happened_at + days.days
      create_site_event_log(trial_event, site, patient_id, happened_at)
    end
  end

  # Private: Create forecasting site event log
  def create_site_event_log(trial_event, site, patient_id, happened_at)
    p "            create site event log(#{trial_event.event_id}), #{happened_at}, #{patient_id}, #{site.site_id}"

    params = {}
    params[:event_id]         = trial_event.event_id
    # params[:trial_event]      = trial_event
    params[:type]             = trial_event.type
    params[:description]      = trial_event.description
    params[:patient_id]       = patient_id
    params[:happened_at]      = happened_at
    params[:happened_at_text] = happened_at.strftime("%m/%d/%Y")
    params[:source]           = SiteEvent::SOURCE[:forecasting]
    params[:status]           = 1
    params[:author]           = "App"
    params[:vpd_id]           = self.vpd.id

    site.site_events.create(params)
  end

  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end


  FIELD_HASH_ARRAY =  [ {name:   "mysql_trial_id",       type: "varchar(255)",     default: "''" },
                        {name:   "title",                type: "varchar(255)",     default: "''" },
                        {name:   "trial_id",             type: "varchar(255)",     default: "''" },
                        {name:   "ctgov_nct",            type: "varchar(255)",     default: "NULL"},
                        {name:   "indication",           type: "varchar(255)",     default: "NULL"},
                        {name:   "status",               type: "varchar(255)",     default: "NULL"},
                        {name:   "max_patients",         type: "int(11)",          default: "NULL"},
                        {name:   "real_patients_count",  type: "int(11)",          default: 0},
                        {name:   "patients_count",       type: "int(11)",          default: 0},
                        {name:   "should_forecast",      type: "boolean",          default: false},
                        {name:   "forecasting_now",      type: "boolean",          default: false},
                        {name:   "mysql_vpd_sponsor_id", type: "varchar(255)",     default: "''"},
                        {name:   "created_at",           type: "timestamp",        default: "NULL"},
                        {name:   "updated_at",           type: "timestamp",        default: "NULL"}
                    ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "trials"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Trial Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = Trial.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
    data.each do |item|
      insert_query = update_query = value_query = ""
      FIELD_HASH_ARRAY.each do |field|
        # p ">>>>>>>>>>>>>field_name : #{field[:name]} => '#{item[field[:name]]}' >>>>>>>>>>>>>>>>"
        insert_query += "`#{field[:name]}`, "
        update_query += "`#{field[:name]}`="
        if field[:type] == "timestamp" || field[:type] == "datetime"
          # p ">>>>>>>>>>>>>datetime>>>>>>>>>>>>>>>>>>>>>>"
          value_query += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
          update_query += item[field[:name]].present? ? "\"#{item[field[:name]].to_s(:db)}\", " : "null, "
        elsif field[:type] == "boolean" || field[:type] == "int(11)"
          value_query += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
          update_query += item[field[:name]].nil? ? "0, " : "#{item[field[:name]]}, "
        else
          if field[:name] == "mysql_trial_id"
            value_query += "\"#{item.id}\", "
            update_query += "\"#{item.id}\", "
          elsif field[:name] == "indication"
            value_query += item[field[:name]].present? ? "\"#{INDICATIONS[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{INDICATIONS[item[field[:name]]]}\", " : "'', "
          elsif field[:name] == "status"
            value_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
            update_query += item[field[:name]].present? ? "\"#{Vpd::STATUS[item[field[:name]]]}\", " : "'', "
          else
            field_name = field[:name].include?("mysql_") ? field[:name].from(6).to(-1) : field[:name]
            value_query += item[field_name].nil? ? "'', " : "\"#{item[field_name].to_s.gsub('"', '\"')}\", "
            update_query += item[field_name].nil? ? "'', " : "\"#{item[field_name].to_s.gsub('"', '\"')}\", "
          end
        end
      end
      insert_query = insert_query.from(0).to(-3)
      value_query = value_query.from(0).to(-3)
      query = insert_query = "INSERT INTO #{MYSQL_TABLE_NAME}(#{insert_query}) VALUES (#{value_query});"
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_trial_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_trial_id`=#{item.id};").first
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
class Vpd < ActiveRecord::Base
  
  # Constants
  #----------------------------------------------------------------------
  MODELS = ["vpd_approver", "vpd_country", "vpd_sponsor", "vpd_currency", "vpd_event", "vpd_ledger_category", "trial", "trial_entry", "trial_event", "trial_passthrough_budget", "trial_schedule", "forecasting", "site", "site_entry", "site_event", "site_passthrough_budget", "site_schedule", "invoice", "passthrough", "transaction", "account", "post", "role"]
  BATACH_QUERY_COUNT = 1
  MYSQL_TABLE_NAME_PREFIX = "dgrants_"
  STATUS = ["NO", "YES"]

  # Associations
  #----------------------------------------------------------------------
  has_many :roles, as: :rolify,         dependent: :destroy
  has_many :accounts,                   dependent: :destroy
  has_many :posts,                      dependent: :destroy
  
  has_many :vpd_sponsors,               dependent: :destroy
  has_many :vpd_countries,              dependent: :destroy
  has_many :vpd_currencies,             dependent: :destroy
  has_many :vpd_mail_templates,         dependent: :destroy
  has_many :vpd_approvers,              dependent: :destroy
  has_many :vpd_reports,                dependent: :destroy
  has_many :vpd_ledger_categories,      dependent: :destroy
  has_many :vpd_events,                 dependent: :destroy

  has_many :trials,                     dependent: :destroy
  has_many :trial_schedules,            dependent: :destroy
  has_many :trial_events,               dependent: :destroy
  has_many :trial_entries,              dependent: :destroy
  has_many :trial_passthrough_budgets,  dependent: :destroy
  has_many :forecastings,               dependent: :destroy

  has_many :sites,                      dependent: :destroy
  has_many :site_schedules,             dependent: :destroy
  has_many :site_events,                dependent: :destroy
  has_many :site_entries,               dependent: :destroy
  has_many :site_passthrough_budgets,   dependent: :destroy
  has_many :passthroughs,               dependent: :destroy
  has_many :invoices,                   dependent: :destroy
  has_many :transactions,               dependent: :destroy

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :name
  validates_uniqueness_of :name, case_sensitive: false
  
  # Scopes
  #----------------------------------------------------------------------
  scope :activated_vpds, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  after_create :setup_vpd
  after_update :set_sync_created_to_vpd_models_if_db_info_changed

  # Flag methods
  #----------------------------------------------------------------------
  # Public: Check if the user is vpd admin of this vpd
  def vpd_admin?(user)
    Role.where(rolify_type: Vpd, rolify_id: self.id, status: 1, user: user).exists?
  end

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Get all activated vpd admin users of this vpd
  def vpd_admins(include_disabled=false)
    include_disabled ? roles.map{|role| role.user if role.user.status==1} : 
                      Role.where(rolify_type: Vpd, rolify_id: self.id, status: 1).map{|role| role.user if role.user.status==1}
  end

  # Public: Get all activated (trial/site)users of this vpd
  def trial_site_users(include_disabled=false)
    users = []
    Trial.where(vpd: self, status: 1).each do |trial|
      if include_disabled
        users << trial.roles.map{|role| role.user if role.user.status==1}
      else
        users << Role.where(rolify_type: Trial, rolify_id: trial.id, status: 1).map{|role| role.user if role.user.status==1}
      end
      Site.where(trial: trial, status: 1).each do |site|
        if include_disabled
          users << site.roles.map{|role| role.user if role.user.status==1}
        else
          users << Role.where(rolify_type: Site, rolify_id: site.id, status: 1).map{|role| role.user if role.user.status==1}
        end
      end
    end
    users.flatten
  end
 
  # Public: Get all activated trials of this vpd
  def activated_trials
    Trial.where(vpd: self, status: 1)
  end

  # Public: Get all activated sites of this vpd
  def activated_sites
    sites = []
    Trial.where(vpd: self, status: 1).each do |trial|
      sites << Site.where(trial: trial, status: 1)
    end
    sites.flatten
  end

  # Mail related methods
  #----------------------------------------------------------------------
  # Public: Get VPD MailTemplate with given template type
  def mailtemplate(template_type)
    VpdMailTemplate.where(vpd: self, status: 1, type: template_type).first
  end

  # Event related methods
  #----------------------------------------------------------------------
  # Public: Get CONTRACT VPD Event with given type
  def start_event(type)
    event_id = type==VpdEvent::TYPE[:single_event] ? "CONTRACT" : "CONSENT"
    VpdEvent.where(vpd: self, event_id: event_id, type: type).first
  end

  # Heroku Scheduler related methods
  #----------------------------------------------------------------------
  # Methods for Mysql custom report begin
  # Class method: Checks MySQL DB Connection
  def self.check_mysql_db_connection(db_host, db_username, db_password, db_name)
    begin
      connection = Mysql2::Client.new(
            :adapter => "mysql2",
            :host => db_host,
            :username => db_username,
            :password => db_password,
            :flags => Mysql2::Client::MULTI_STATEMENTS
      )
      connection_exist = true
      connection.query("USE #{db_name};")
      db_exist = true
    rescue Exception => e
      p e
    end
    connection.close if connection.present?
    {connection_exist: connection_exist, db_exist: db_exist}
  end

  # Class method: Scheduler function to dump from mongo to mysql
  def self.mongo_to_mysql_dump
    ## Remote SQL Host
    # db_host = "dbf.dd-sandbox.com"
    # db_username = "data"
    # db_password = "myDATAiss@fe"

    ## Local SQL Host
    # db_host = "localhost"
    # db_username = "root"
    # db_password = ""

    Vpd.all.each do |vpd|
      if vpd.db_host.present? && vpd.username.present? && !vpd.password.nil? && vpd.db_name.present?
        connection = Mysql2::Client.new(
              :adapter => "mysql2",
              :host => vpd.db_host,
              :username => vpd.username,
              :password => vpd.password,
              :flags => Mysql2::Client::MULTI_STATEMENTS
        )
        p ">>>>>>>>>vpd : #{vpd.name}>>>>>>>>>"
        # connection.query("CREATE DATABASE IF NOT EXISTS #{db_name} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;") 
        connection.query("USE #{vpd.db_name};")
        MODELS.each do |model|
          model = model.camelize.constantize
          model.data_to_mysql(vpd, connection)
        end
        connection.close
      end
    end
  end

  # Public: Creates MySQL table with table schema information
  def self.create_mysql_table(connection, table_name, field_hash_array)
    sql_create_table = "CREATE TABLE IF NOT EXISTS #{table_name} ("
    field_hash_array.each_with_index do |field, index|
      sql_create_table += "`#{field[:name]}` #{field[:type]} #{field[:name]=="created_at" || field[:name]=="updated_at" ? "" : "DEFAULT"} #{field[:default]}#{index+1<field_hash_array.count ? ',' : ''}"
    end
    sql_create_table = sql_create_table + ");"
    connection.query(sql_create_table)
  end

  # Public: Drops all MySQL tables from VPD databases
  def self.drop_mysql_tables
    Vpd.all.each do |vpd|
      if vpd.db_host.present? && vpd.username.present? && !vpd.password.nil? && vpd.db_name.present?
        connection = Mysql2::Client.new(
              :adapter => "mysql2",
              :host => vpd.db_host,
              :username => vpd.username,
              :password => vpd.password,
              :flags => Mysql2::Client::MULTI_STATEMENTS
        )
        p ">>>>>>>>>vpd : #{vpd.name}>>>>>>>>>"
        # connection.query("CREATE DATABASE IF NOT EXISTS #{db_name} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;") 
        connection.query("USE #{vpd.db_name};")
        drop_tables_query = "DROP TABLE IF EXISTS "
        MODELS.each do |model|
          model = model.camelize.constantize
          drop_tables_query += "#{model::MYSQL_TABLE_NAME}, "
          p "DROP TABLE #{model::MYSQL_TABLE_NAME}"
        end
        connection.query(drop_tables_query.to(-3)+";") if drop_tables_query.end_with?(", ")
        connection.close
      end
    end
  end

  def self.set_sync_created
    MODELS.each do |model|
      model = model.camelize.constantize
      model.all.each do |item|
        item.update_attributes(sync: 2)
      end
    end
  end

  # Public: Set sync attributes of all models data as created belonging to vpd if any db info changed
  def set_sync_created_to_vpd_models_if_db_info_changed
    if db_host_changed? || db_name_changed?
      set_sync_created_to_vpd_models
    end
  end

  # Public: Set sync attributes of all models data as created belonging to vpd
  def set_sync_created_to_vpd_models
    MODELS.each do |model|
      model = model.camelize.constantize
      model.where(vpd: self).each do |item|
        item.update_attributes(sync: 2)
      end
    end
  end

  # Public: Set sync attributes of all models data as updated belonging to vpd
  def set_sync_updated_to_vpd_models
    MODELS.each do |model|
      model = model.camelize.constantize
      model.where(vpd: self).each do |item|
        item.update_attributes(sync: 1)
      end
    end
  end

  # Methods for Mysql custom report end

  # Private methods
  #----------------------------------------------------------------------
  private
  def setup_vpd
    VpdMailTemplate::MAIL_TYPE.each do |key, val|
      template = self.vpd_mail_templates.build(type: val, subject: VpdMailTemplate::MAIL_SUBJECT[key], body: VpdMailTemplate::MAIL_BODY[key])
      template.save
    end

    Country.activated_countries.each do |country|
      vpd_country = self.vpd_countries.build(country: country)
      vpd_country.save
    end

    Currency.activated_currencies.each do |currency|
      vpd_currency = self.vpd_currencies.build(currency: currency)
      vpd_currency.save
    end

    Sponsor.activated_sponsors.each do |sponsor|
      vpd_sponsor = self.vpd_sponsors.build(sponsor: sponsor)
      vpd_sponsor.save
    end

    description = "Site is ready to start delivering work"
    vpd_event = self.vpd_events.build(event_id: "CONTRACT", type: VpdEvent::TYPE[:single_event], description: description)
    vpd_event.save

    description = "Patient is ready to start study activities"
    vpd_event = self.vpd_events.build(event_id: "CONSENT", type: VpdEvent::TYPE[:patient_event], description: description)
    vpd_event.save
  end
  handle_asynchronously :setup_vpd, priority: 10, run_at: Proc.new {1.second.from_now}
end
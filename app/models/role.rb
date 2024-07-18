class Role < ActiveRecord::Base

  # Constants
  #----------------------------------------------------------------------
  ROLE = {super_admin: 1, vpd_admin: 2, trial_admin: 3, trial_readonly: 5, trial_associate: 8, site_admin: 13, site_readonly: 21, site_user: 34}

  # Associations
  #----------------------------------------------------------------------
  belongs_to :rolify, polymorphic: true
  belongs_to :user
  belongs_to :vpd

  has_one    :vpd_approver

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :role, :user
  validates_uniqueness_of :user, scope: :rolify

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_roles, -> {where(status: 1)}
  scope :vpd_roles,       -> {where(rolify_type: Vpd)}
  scope :trial_roles,     -> {where(rolify_type: Trial)}
  scope :site_roles,      -> {where(rolify_type: Site)}

  # Callbacks
  #----------------------------------------------------------------------
  after_update  :sync_for_update

  # Attributes methods
  #----------------------------------------------------------------------
  # Public: Get trial of this role
  def trial
    if rolify.class == Vpd
      nil
    elsif rolify.class == Trial
      rolify
    else
      rolify.trial
    end
  end

  # Public: Get site of this role
  def site
    if rolify.class == Vpd
      nil
    elsif rolify.class == Trial
      nil
    else
      rolify
    end
  end

  # Public: Get role name string of this role
  def role_label
    case role
    when ROLE[:vpd_admin]
      ["VPD Admin", "A"]
    when ROLE[:trial_admin] 
      ["Trial Admin", "TA"]
    when ROLE[:trial_readonly]
      ["Trial Admin Read-Only", "TAR"]
    when ROLE[:trial_associate]
      ["Monitor", "M"]
    when ROLE[:site_admin]
      ["Site Admin", "SA"]
    when ROLE[:site_readonly]
      ["Site Admin Read-Only", "SAR"]
    when ROLE[:site_user]
      ["Site User", "SU"]
    end
  end

  # Public: Get full role label
  def full_role_label
    case role
    when ROLE[:vpd_admin]
      "VPD Admin"
    when ROLE[:trial_admin] 
      "Trial Admin"
    when ROLE[:trial_readonly]
      "Trial Admin(Read-Only)"
    when ROLE[:trial_associate]
      "Site Monitor"
    when ROLE[:site_admin]
      "Site Admin"
    when ROLE[:site_readonly]
      "Site Admin(Read-Only)"
    when ROLE[:site_user]
      "Site User"
    end
  end

  # Public: Get user email string of this role
  def email
    user.email
  end

  STATUS = %w(Disabled Acitve)
  # Public: Get status label of this role
  def status_label
    STATUS[status]
  end

  # Public: Set sync to synced status
  def sync_for_synced
    self.update_attributes(sync: 0)
  end

  # Private methods
  #----------------------------------------------------------------------
  private  
  # Callback methods
  #----------------------------------------------------------------------
  # Private: Set sync to updated status
  def sync_for_update
    self.update_attributes(sync: 1) if !self.sync_changed?  &&  sync != 1
  end

  FIELD_HASH_ARRAY =  [ { name:   "mysql_role_id",                    type: "int(11)",        default: "NULL"},
                        { name:   "role",                             type: "int(11)",        default: 0 },
                        { name:   "invitation_sent_date",             type: "datetime",       default: "NULL" },
                        { name:   "username",                         type: "varchar(255)",   default: "''" },
                        { name:   "email",                            type: "varchar(255)",   default: "''" },
                        { name:   "mysql_user_id",                    type: "int(11)",        default: "NULL" },
                        { name:   "role_label",                       type: "varchar(255)",   default: "''" },
                        { name:   "mysql_trial_id",                   type: "int(11)",        default: "NULL" },
                        { name:   "mysql_site_id",                    type: "int(11)",        default: "NULL" },
                        { name:   "status",                           type: "varchar(255)",   default: "NULL" },
                        { name:   "created_at",                       type: "timestamp",      default: "NULL"},
                        { name:   "updated_at",                       type: "timestamp",      default: "NULL"}
                      ]
  MYSQL_TABLE_NAME = Vpd::MYSQL_TABLE_NAME_PREFIX + "roles"

  def self.data_to_mysql(vpd, connection)
    p ">>>>>>>>>>>>Role Data To Mysql---------vpd : #{vpd.name}>>>>>>>>>>>>>>>"
    Vpd.create_mysql_table(connection, MYSQL_TABLE_NAME, FIELD_HASH_ARRAY)

    query_count=0 and queries=""
    data = Role.where("vpd_id = #{vpd.id} AND (sync > 0 OR sync IS NULL)")
    data.each do |item|
      insert_query = update_query = value_query = ""
      FIELD_HASH_ARRAY.each do |field|
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
            if field[:name] == "mysql_role_id"
              value_query  += "#{item.id}, "
              update_query += "#{item.id}, "
            elsif field[:name] == "mysql_trial_id"
              value_query  += (item.role >= ROLE[:trial_admin]) ? "#{item.trial.id}, " : "NULL, "
              update_query += (item.role >= ROLE[:trial_admin]) ? "\"#{item.trial.id}, " : "NULL, "
            elsif field[:name] == "mysql_site_id"
              value_query  += (item.role >= ROLE[:trial_associate]) ? "#{item.site.id}, " : "NULL, "
              update_query += (item.role >= ROLE[:trial_associate]) ? "#{item.site.id}, " : "NULL, "
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
          elsif field[:name] == "role_label"
            value_query += "\"#{item.full_role_label}\", "
            update_query += "\"#{item.full_role_label}\", "
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
      update_query = "UPDATE #{MYSQL_TABLE_NAME} SET #{update_query.from(0).to(-3)} WHERE `mysql_role_id`=#{item.id}"
      if item.sync == 1
        results = connection.query("SELECT count(*) as count FROM #{MYSQL_TABLE_NAME} where `mysql_role_id`=#{item.id};").first
        p ">>>>>>>>>>>>>>count #{results["count"]}>>>>>>>>>>>>>>>>>>>>"
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
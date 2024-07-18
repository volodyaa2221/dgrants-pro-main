class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable, 
         :timeoutable, timeout_in: Dgrants::Application::CONSTS[:expire_time]

  # Constants
  #----------------------------------------------------------------------
  ## API login session expiration period
  ADMIN_EMAILS = [Dgrants::Application::CONSTS[:contact_email]]

  # Associations
  #----------------------------------------------------------------------
  belongs_to  :manager, class_name: "User"
  has_many    :members, class_name: "User", foreign_key: "manager_id"

  has_one     :vpd_approver, dependent: :destroy
  has_many    :roles,   dependent: :destroy
  has_many    :trial_entries
  has_many    :site_entries

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :member_type

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_users, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------
  before_save   :ensure_authentication_token
  after_create  :setup_user

  # Role related methods
  #----------------------------------------------------------------------
  # Public: Get user's top role in system
  def member_type_label
    case member_type
      when Role::ROLE[:super_admin]
        ["Super Admin", "A"]
      when Role::ROLE[:vpd_admin]
        ["VPD Admin", "A"]
      when Role::ROLE[:trial_admin] 
        ["Trial Admin", "TA"]
      when Role::ROLE[:trial_readonly]
        ["Trial Admin Read-Only", "TAR"]
      when Role::ROLE[:trial_associate]
        ["Monitor", "M"]
      when Role::ROLE[:site_admin]
        ["Site Admin", "SA"]
      when Role::ROLE[:site_readonly]
        ["Site Admin Read-Only", "SAR"]
      when Role::ROLE[:site_user]
        ["Site User", "SU"]      
    end
  end

  # Public: Check if this user is super level user(super admin) or not
  def super_admin?
    member_type == Role::ROLE[:super_admin]  &&  status == 1
  end

  # Public: Check if this user is vpd level user(vpd admin) or not
  # if trial is selected, check if the user is really vpd admin in that trial.
  def vpd_level_user?(trial=nil)
    if super_admin?
      true
    else 
      if trial.present?
        member_type == Role::ROLE[:vpd_admin]  &&  trial.vpd.vpd_admin?(self)
      else
        member_type <= Role::ROLE[:vpd_admin]  &&  Role.where(user: self, rolify_type: Vpd, status: 1).exists?
      end
    end
  end

  # Public: Check if this user is real vpd admin or not
  # Note: for LHS menus
  def vpd_admin?(trial=nil) 
    if trial.present?
      member_type == Role::ROLE[:vpd_admin]  &&  trial.vpd.vpd_admin?(self)
    else 
      member_type == Role::ROLE[:vpd_admin]  &&  Role.where(user: self, rolify_type: Vpd, status: 1).exists?
    end
  end

  # Public: Check if this user is trial level user(trial admin or trial readonly) or not
  def trial_level_user?(trial=nil)
    if super_admin?
      true
    else 
      if trial.present?
        vpd_level_user?(trial) || trial.trial_admin?(self) || trial.trial_readonly?(self)
      else
        member_type <= Role::ROLE[:trial_readonly]  &&  Role.where(user: self, rolify_type: [Vpd, Trial], status: 1).exists?
      end
    end
  end

  # Public: Check if this user can edit trial level or not
  def trial_editable?(trial)
    trial_level_user?(trial) && !trial.trial_readonly?(self)
  end

  # Public: Check if this user can edit trial level or not
  def site_level_user?(site=nil)
    if super_admin?
      true
    else 
      if site.present?
        trial_level_user?(site.trial) || Role.where(user: self, rolify_type: Site, status: 1, rolify_id: site.id).exists?
      else
        member_type <= Role::ROLE[:site_user]  &&  Role.where(user: self, rolify_type: Site, status: 1).exists?
      end
    end
  end

  # Public: Check if this user can edit site details
  def site_editable?(site)
    site_level_user?(site) && !site.trial.trial_readonly?(self) && !site.site_readonly?(self)
  end

  # Public: Check if this user is higher than trial associate
  def tcm_level_user?(site)
    trial_editable?(site.trial) || site.trial_associate?(self)
  end

  # Trial related methods
  #----------------------------------------------------------------------
  # Public: Get activated vpd of this user with his role
  def vpd
    roles = Role.where(user: self, rolify_type: Vpd, status: 1)
    roles.exists? ? roles.first.rolify : nil
  end

  # Public: Get activated trials of this user with his role
  def trials(include_disabled=false)
    if super_admin?
      include_disabled ? Trial.all : Trial.where(status: 1)
    else
      trial_ids = Role.where(user: self, rolify_type: Trial, status: 1).map(&:rolify_id)
      trial_ids = trial_ids.concat(Role.where(user: self, rolify_type: Site, status: 1).map{|role| role.trial.id})
      temp = Role.where(user: self, rolify_type: Vpd, status: 1).map do |role|
        vpd = role.rolify
        include_disabled ? vpd.trials.map(&:id) : Trial.where(vpd: vpd, status: 1).map(&:id)
      end
      trial_ids = trial_ids.concat(temp)
      include_disabled ? Trial.where(id: trial_ids.flatten.compact.uniq) : Trial.where(id: trial_ids.flatten.compact.uniq, status: 1)
    end
  end

  # Public: Get trial role of given user in this trial
  def trial_role(trial)
    role = Role.where(user: self, rolify_type: Trial, rolify: trial)
    role.exists? ? role.first : nil 
  end

  # Site related methods
  #----------------------------------------------------------------------
  # Public: Get all sites of this user with his role
  # Note: if site count is 1, user will go to site panel after login
  def sites(include_disabled=false)
    site_ids = Role.where(user: self, rolify_type: Site, status: 1).map(&:rolify_id)
    include_disabled ? Site.where(id: site_ids) : Site.where(id: site_ids, status: 1)
  end

  # Public: Get all sites with trial
  # Note: if the site count is 1, after login
  def sites_of_trial(trial)
    sites.where(trial: trial, status: 1)
  end

  # Public: Get role of this user in the given site
  def site_role(site)
    role = Role.where(user: self, rolify_type: Site, rolify: site)
    role.exists? ? role.first : nil 
  end

  # User Attribute related methods
  #----------------------------------------------------------------------
  # Public: Get full name of user
  def name
    if first_name.present?
      name = [first_name, last_name].join(" ")
    end
    name.present? ? name : ''
  end

  # Public: Get elapsed time from last login
  def time_span_in_DHMS
    time1 = Time.now
    time2 = current_sign_in_at
    days, remaining = (time1 - time2).to_i.abs.divmod(86400)
    hours, remaining = remaining.divmod(3600)
    minutes, seconds = remaining.divmod(60)
    [days, hours, minutes, seconds]
  end

  # Public: Get last logged in time string of current user
  def last_login
    if current_sign_in_at.present?
      distance = self.time_span_in_DHMS
      if distance[0] > 1
        return distance[0].to_s + "d"
      elsif distance[1] > 1
        return distance[1].to_s + "h(s)"
      else
        "Online"
      end
    else
      "N/A"
    end
  end

  STATUS = %w(Disabled Acitve)
  # Public: Get status label of current user
  def status_label
    STATUS[status]
  end

  # Collection methods
  #----------------------------------------------------------------------
  TASK_STATUS = { budget_inactive: 0, missing_banking_details: 1, invoice_due_for_submission: 2, passthroughs_need_approval: 3, requiring_events_approval: 4 }
  
  # Public: Gets tasks of user
  def tasks
    user_tasks = []
    if vpd_admin? || !vpd_level_user?
      trials(include_disabled=false).each do |trial|
        t_sites = trial.sites.activated_sites
        t_sites.each do |site|
          if site_editable?(site)
            e = {trial_id: trial.trial_id, country: site.country_name, site_id: site.site_id, trial: trial, site: site}
            
            if site.site_schedule.schedule_status < 2
              user_tasks << e.merge(status: TASK_STATUS[:budget_inactive])
            end

            if site.payment_verified < Site::PAYMENT_VERIFIED[:presumed_good]
              user_tasks << e.merge(status: TASK_STATUS[:missing_banking_details])
            end

            if site.is_invoice_overdue == 1
              user_tasks << e.merge(status: TASK_STATUS[:invoice_due_for_submission])
            end

            if trial.trial_admin?(self) && Passthrough.has_pending?(site)
              user_tasks << e.merge(status: TASK_STATUS[:passthroughs_need_approval])
            end

            if site.has_pending_events?
              user_tasks << e.merge(status: TASK_STATUS[:requiring_events_approval])
            end
          end
        end
      end
    end
    user_tasks
  end

  # Promote Invitation related methods
  #----------------------------------------------------------------------
  # Public: Remove all user roles
  def remove_all_roles
    self.roles.destroy_all
    self.update_attributes(member_type: 100)
  end

  # Public: Remove user roles in the given vpd
  def remove_roles_in_vpd(vpd)
    trials = vpd.trials
    Role.where(user: self, rolify_type: Vpd, rolify_id: vpd.id).destroy_all
    Role.where(user: self, rolify_type: Trial, rolify_id: trials.map(&:id)).destroy_all
    site_ids = trials.map do |trial|
      trial.sites.map(&:id)
    end
    Role.where(user: self, rolify_type: Site, rolify_id: site_ids.flatten).destroy_all
  end

  # Public: Remove user roles in the given trial
  def remove_roles_in_trial(trial)
    Role.where(user: self, rolify_type: Trial, rolify_id: trial.id).destroy_all
    Role.where("user_id = #{self.id} AND rolify_type = 'Site' AND rolify_id IN (#{trial.sites.map(&:id).join(",")})").destroy_all
  end

  # Public: Remove user roles in the given site
  def remove_roles_in_site(site)
    Role.where(user: self, rolify_type: Site, rolify_id: site.id).destroy_all
  end


  # API Invitation related methods
  #----------------------------------------------------------------------
  ## Sends invitation email for new/invited user
  def setup_user(confirm_needed=true)
    if confirm_needed && !ADMIN_EMAILS.include?(email) && immediate_to_confirm
      send_confirmation_instructions
    end
    save
  end

  # Mail related methods
  #----------------------------------------------------------------------
  # Public: Return object(Trial or Site) which this user was invited to
  def invited_to_object
    model = self.invited_to_type.constantize
    model.find(self.invited_to_id)
  end

  # Devise methods
  #----------------------------------------------------------------------
  # Public: Reset password in email confirmation
  def attempt_set_password(params)
    p = {}
    p[:password] = params[:password]
    p[:password_confirmation] = params[:password_confirmation]
    update_attributes(p)
  end

  # Public: Check if password exists or not
  def has_no_password?
    self.encrypted_password.blank?
  end

  # Public: new function to provide access to protected method unless_confirmed
  def only_if_unconfirmed
    pending_any_confirmation {yield}
  end

  # Public: Make authentication_token
  def ensure_authentication_token
    self.authentication_token ||= generate_authentication_token
  end

  # Public: Check if the user has his own profile or not
  def has_profile?
    self.organization.present?
  end

  # Public: Check this user has invalid profile
  def invalid_profile?
    self.profile_id.blank? || self.profile_id == self.email
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  # Private: Generate profile access token for calling dProfile
  def profile_token
    Digest::SHA2.hexdigest("Drugdev" + Date.today.to_s)
  end

  # Private: Generate authentication token
  # 
  # Returns token string
  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end
end
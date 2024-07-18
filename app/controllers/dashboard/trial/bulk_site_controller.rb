class Dashboard::Trial::BulkSiteController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial  
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user

  # Trial Bulk Site actions
  # ----------------------------------------
  # GET   /dashboard/trial/:trial_id/new_upload(.:format)
  def new_upload
    respond_to do |format|
      format.html
      format.js
    end
  end

  # GET   /dashboard/trial/:trial_id/template(.:format) 
  def template
    options = {col_sep: "\t"}
    template_csv = CSV.generate(options = {}) do |csv|
      csv << ["Site_ID", "Site_Name", "Site_Country", "Site_State", "Site_City", "Site_Address", "Site_ZIP", "Site_Admin",          "Trial_Associate"]
      csv << ["1",      "Example Hosp", "ARGENTINA",  "VICTORIA",   "ARMADALE",  "113 HIGH ST",  "3143",     "sa1@latholdings.com", "ta1@latholdings.com"]
    end
    respond_to do |format|
      #format.html { render layout: false }
      format.csv  { send_data template_csv }
      # format.csv  { render text: template_string }
      # format.xls  { send_data template_csv }
    end
  end

  # POST  /dashboard/trial/:trial_id/upload_config(.:format) 
  def upload_config
    csv_file  = params[:csv_file]
    headers   = CSV.read(csv_file.path, headers: true).headers
    headers   << "Reason"

    keys = []
    headers.each do |header|
      keys << "site_id"                 if header == "Site_ID" 
      keys << "name"                    if header == "Site_Name" 
      keys << "country_name"            if header == "Site_Country" 
      keys << "state"                   if header == "Site_State" 
      keys << "city"                    if header == "Site_City" 
      keys << "address"                 if header == "Site_Address" 
      keys << "zip_code"                if header == "Site_ZIP" 
      keys << "site_admin"              if header == "Site_Admin" 
      keys << "trial_associate"         if header == "Trial_Associate" 
    end
    
    unless keys.include?("site_id")
      render json: {failure: {msg: "There isn't a SITE_ID coloumn"}} and return                  
    end

    email_reg  = /^.+@.+$/
    error_list = []
    error_list << headers.join(",")

    vpd   = @trial.vpd
    CSV.foreach(csv_file.path) do |row|
      next if row[0] == "Site_ID" # if header row, next
      has_error  = false
      data = {}
      site_admin = nil
      trial_associate = nil
      i = 0
      row.each do |cell|
        key = keys[i]
        if cell.present?
          if key == "site_admin"
            site_admin = cell.strip
          elsif key == "trial_associate"
            trial_associate = cell.strip
          else
            key = key.to_sym
            data[key] = cell.strip
          end
        end
        i += 1
      end

      if data[:site_id].nil? || data[:site_id].blank?
        row << "Site_ID can't be blank"
        has_error = true
      else 
        data[:site_id] = data[:site_id].upcase
      end

      if data[:country_name].present?  &&  !data[:country_name].blank?
        data[:country_name] = data[:country_name].titleize
        vpd_country = @trial.vpd.vpd_countries.where(name: data[:country_name]).first
        if vpd_country.nil?
          row << "Given Site_Country isn't in VPD countries"
          has_error = true
        else
          country = vpd_country.country
          data[:vpd_country_id] = vpd_country.id.to_s
          data[:country_id] = country.id.to_s
        end
      else 
        data[:country_name] = "UNDEFINED" if keys.include?("country_name")
        data[:vpd_country] = nil
        data[:country] = nil
        data[:state] = nil
        data[:state_code] = nil    
      end
      if data[:country_id].present? && data[:state].present?
        data[:state] = data[:state].titleize
        state = Carmen::Country.named(data[:country_name]).subregions.count==0 ? '' : Carmen::Country.named(data[:country_name]).subregions.named(data[:state])
        if state.nil?
          row << "Given Site_State isn't valid in #{data[:country_name]}"
          has_error = true
        else
         data[:state_code] = state.code
        end
      end
      data[:city] = data[:city].capitalize if data[:city].present?

      unless has_error
        site = Site.where(trial: @trial, site_id: data[:site_id]).first
        if site.present?
          site.assign_attributes(data)
        else
          if data[:country_id].nil?
            data[:country_name] = "UNDEFINED"
          end
          site = @trial.sites.build(data)
        end

        if site.save
          if site_admin.present? && !!(site_admin =~ email_reg)
            result = invite_site_user(site, site_admin, Role::ROLE[:site_admin])
            if result.class.name == "String"
              row << result
              has_error = true
            end
          end
          if trial_associate.present? && !!(trial_associate =~ email_reg)
            result = invite_site_user(site, trial_associate, Role::ROLE[:trial_associate])
            if result.class.name == "String"
              row << result
              has_error = true
            end
          end
        else 
          row << site.errors.full_messages.first
          has_error = true
        end
      end

      if has_error
        error_list << row.join(",")
      end
    end

    if error_list.count > 1
      render text: error_list.join("<br/>").html_safe
      # data = {failure:{msg:error_list.join("<br/>").html_safe}}
    else
      redirect_to sites_dashboard_trial_trial_path(@trial)
      # render json: {success:{msg: "ok"}}
    end    
  end


  # Private methods
  # ----------------------------------------
  private

  # Private: Invite new users to site by csv uploading
  def invite_site_user(site, email, role)
    user = User.where(email: email).first
    p_role = role
    invited_to = {type: Site.name, id: site.id.to_s}

    if user.present?
      return t("controllers.sites.user.failure_super_admin") if user.super_admin?
      return t("controllers.sites.user.failure_vpd_admin") if site.vpd.vpd_admin?(user)
      return t("controllers.sites.user.failure_trial_admin") if site.trial.trial_admins.include?(user)
      return t("controllers.sites.user.failure_exist_user") if site.users.include?(user)

      role = Role.where(rolify_type: Site, rolify_id: site.id, role: p_role).first
      if role.present?
        if user.update_attributes(manager: current_user)
          if user.confirmation_token.present?
            user.send_confirmation_instructions
          else
            send_invitation(user, role.role, site)
          end
          data = true
        end
      else
        role = user.roles.build(rolify: site, role: p_role, vpd: site.vpd)
        if role.save
          member_type = p_role < user.member_type ? p_role : user.member_type
          user.update_attributes(manager: current_user, member_type: member_type, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
          send_invitation(user, role.role, site)
          data = true
        else
          data = "Failed to invite #{email}"
        end
      end
    else
      password = (0...8).map { (97 + rand(26)).chr }.join
      user = User.new(email: email, password: password, password_confirmation: password, 
                      manager: current_user, member_type: p_role, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
      role = user.roles.build(rolify: site, role: p_role, vpd: site.vpd)
      user.skip_confirmation!
      if user.save
        role.save
        data = true
      else
        data = "Failed to invite #{email}"
      end
    end
    data
  end

  # Private: Sends mail
  def send_invitation(user, role, site)
    if role == Role::ROLE[:trial_associate]
      UserMailer.invited_trial_associate(user, site).deliver
    elsif role == Role::ROLE[:site_admin] || role == Role::ROLE[:site_readonly]
      UserMailer.invited_site_admin(user, site).deliver
    elsif role == Role::ROLE[:site_user]
      UserMailer.invited_site_user(user, site).deliver
    end
  end
end
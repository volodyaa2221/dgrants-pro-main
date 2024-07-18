module DashboardHelper

  # Public: Check if the user is super admin
  def authenticate_super_admin
    if current_user.super_admin?
      return true
    else
      flash[:error] = "Access is for super admin only"
      redirect_to request.referrer
    end
  end

  # Public: Get VPD options for all available VPDs
  def vpd_options
    Vpd.activated_vpds.order(name: :asc).map do |vpd|
      [vpd.name, vpd.id.to_s]
    end 
  end

  # Public: Get Trial options for all available Trials
  def trial_options(vpd)
    vpd = Vpd.find(vpd) unless vpd.class.name == "Vpd"
    Trial.where(vpd: vpd, status: 1).order(trial_id: :asc).map do |trial|
      [trial.trial_id, trial.id.to_s]
    end
  end

  # Public: Get Site options for all available Sites
  def site_options(trial)
    trial = Trial.find(trial) unless trial.class.name == "Trial"
    Site.where(trial: trial, status: 1).map do |site|
      [site.site_id, site.id.to_s]
    end
  end

  # Public: Get Site options for all available Trials of a user (used in Task dropdown filters)
  def task_site_options(trials)
    opts = []
    trials.each do |trial|
      opts.concat(site_options(trial))
    end
    opts.unshift(["All Sites", " "])
  end

  # Public: Get Vpd Country options for all available Vpd Countrys of a user (used in Task dropdown filters)
  def task_vpd_countries_options(trials)
    opts = []
    vpd_countries = []
    trials.each do |trial|
      vpd_countries.concat(trial.vpd_countries)
    end
    vpd_countries.uniq!
    opts = vpd_countries.map { |vpd_country| [vpd_country.name, vpd_country.name] }
    opts.unshift(["All Countries", " "])
  end

  # Public: Get all available roles
  def user_roles
    roles = Role::ROLE.map do |key, val|
      case val
        when Role::ROLE[:super_admin]
          ["Super Admin", val]
        when Role::ROLE[:vpd_admin] 
          ["VPD Admin", val]
        when Role::ROLE[:trial_admin] 
          ["Trial Admin", val]
        when Role::ROLE[:trial_readonly] 
          ["Trial Admin (Read Only)", val]
        when Role::ROLE[:trial_associate] 
          ["Monitor", val]
        when Role::ROLE[:site_admin] 
          ["Site Admin", val]
        when Role::ROLE[:site_readonly] 
          ["Site User(Read Only)", val]
        when Role::ROLE[:site_user] 
          ["Site User", val]
      end
    end
    roles.compact
  end

  # Public: Invite user(VPD Admin, Trial Admin, Site Admin, etc)
  def invite_user(email, p_role, promote_to, vpd=nil, trial=nil, site=nil, role_id=nil)
    email = email.downcase
    user = User.where(email: email).first

    if user.present?
      if p_role == Role::ROLE[:super_admin]
        return {failure: {msg: t("controllers.dashboard.user.failure_super_admin"), element_id: "user_email", need_confirm: false}} if user.super_admin?
        if user.roles.exists?
          if !to_b(promote_to)
            return {failure: {msg: t("controllers.dashboard.user.failure_exist_user"), element_id: "user_email", need_confirm: true}}
          else
            user.remove_all_roles
          end
        end

        if user.update_attributes(manager: current_user, member_type: p_role, invited_to: nil)
          data = {success:{msg: "Invited new Super Admin", id: user.id.to_s, name: user.email}}        
        else
          data = {failure:{msg: "Failed to invite", id: user.id.to_s, element_id: "user_email"}}
        end

      elsif p_role == Role::ROLE[:vpd_admin]
        if role_id.nil?
          return {failure: {msg: t("controllers.vpds.admin.failure_super_admin"), element_id: "user_email", need_confirm: false}} if user.super_admin?
          return {failure: {msg: t("controllers.vpds.admin.failure_vpd_admin"), element_id: "user_email", need_confirm: false}} if user.vpd_level_user?
          if vpd.trial_site_users(include_disabled=true).include?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.vpds.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}  
            else
              user.remove_roles_in_vpd(vpd)
            end
          end
        else
          if user.super_admin?
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.dashboard.user.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_all_roles
            end
          elsif user.vpd_level_user? || vpd.trial_site_users(include_disabled=true)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.vpds.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_vpd(vpd)
            end
          end

          role = Role.where(id: role_id)
          if role.exists?
            role = role.first
            unless role.destroy
              return {failure: {msg: "Failed to change role", element_id: "user_email", need_confirm: true}}
            end
          end
        end

        role = user.roles.build(rolify: vpd, role: p_role, vpd: vpd)
        if role.save
          invited_to = {type: Vpd.name, id: vpd.id.to_s}
          member_type = user.member_type <= p_role ? user.member_type : p_role
          if user.update_attributes(manager: current_user, member_type: member_type, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
            data = {success:{msg: "Invited new VPD Admin", id: user.id.to_s, name: user.email}}        
          else
            data = {failure:{msg: user.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
          end
        else
          data = {failure:{msg: role.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
        end
      
      elsif p_role > Role::ROLE[:vpd_admin]  &&  p_role <= Role::ROLE[:trial_readonly]
        if role_id.nil?
          return {failure: {msg: t("controllers.trials.admin.failure_super_admin"), element_id: "user_email"}} if user.super_admin?
          return {failure: {msg: t("controllers.trials.admin.failure_vpd_admin"), element_id: "user_email"}} if trial.vpd.vpd_admin?(user)
          return {failure: {msg: t("controllers.trials.admin.failure_trial_admin"), element_id: "user_email"}} if trial.trial_admins(include_disabled=true).include?(user)
          if trial.site_users(include_disabled=true).include?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.trials.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_trial(trial)
            end
          end
        else
          if user.super_admin?
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.dashboard.user.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_all_roles
            end
          elsif trial.vpd.vpd_admin?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.vpds.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_vpd(trial.vpd)
            end
          elsif trial.trial_admins(include_disabled=true).include?(user) || trial.site_users(include_disabled=true).include?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.trials.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_trial(trial)
            end
          end

          role = Role.where(id: role_id)
          if role.exists?
            role = role.first
            unless role.destroy
              return {failure: {msg: "Failed to change role", element_id: "user_email", need_confirm: true}}
            end
          end
        end

        role = user.roles.build(rolify: trial, role: p_role, vpd: trial.vpd)
        if role.save
          invited_to = {type: Trial.name, id: trial.id.to_s}
          member_type = user.member_type <= p_role ? user.member_type : p_role
          if user.update_attributes(manager: current_user, member_type: member_type, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
            data = {success:{msg: "Invited new Trial Admin", id: user.id.to_s, name: email}}
          else
            data = {failure:{msg: user.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
          end  
        else
          data = {failure:{msg: role.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
        end

      elsif p_role > Role::ROLE[:trial_readonly]
        if role_id.nil?
          return {failure: {msg: t("controllers.sites.user.failure_super_admin"), element_id: "user_email"}} if user.super_admin?
          return {failure: {msg: t("controllers.sites.user.failure_vpd_admin"), element_id: "user_email"}} if site.trial.vpd.vpd_admin?(user)
          return {failure: {msg: t("controllers.sites.user.failure_trial_admin"), element_id: "user_email"}} if site.trial.trial_admins(include_disabled=true).include?(user)
          return {failure: {msg: t("controllers.sites.user.failure_exist_new_user"), element_id: "user_email"}} if site.users(include_disabled=true).include?(user)
        else
          if user.super_admin?
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.dashboard.user.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_all_roles
            end
          elsif site.trial.vpd.vpd_admin?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.vpds.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_vpd(site.trial.vpd)
            end
          elsif site.trial.trial_admins(include_disabled=true).include?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.trials.admin.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_trial(site.trial)
            end
          elsif site.users(include_disabled=true).include?(user)
            if !to_b(promote_to)
              return {failure: {msg: t("controllers.sites.user.failure_exist_user"), element_id: "user_email", need_confirm: true}}
            else
              user.remove_roles_in_site(site)
            end
          end
          role = Role.where(id: role_id)
          if role.exists?
            role = role.first
            unless role.destroy
              return {failure: {msg: "Failed to change role", element_id: "user_email", need_confirm: true}}
            end
          end
        end  

        role = user.roles.build(rolify: site, role: p_role, vpd: site.vpd)
        if role.save
          invited_to = {type: Site.name, id: site.id.to_s}
          member_type = user.member_type <= p_role ? user.member_type : p_role
          if user.update_attributes(manager: current_user, member_type: member_type, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
            data = {success:{msg: "Invited new Site User", id: user.id.to_s, name: email}}
          else
            data = {failure:{msg: user.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
          end          
        else
          data = {failure:{msg: role.errors.full_messages.first, id: user.id.to_s, element_id: "user_email"}}
        end
      end          
        
    else
      password = (0...8).map { (97 + rand(26)).chr }.join
      if p_role == Role::ROLE[:super_admin]
        user = User.new(email: email, password: password, password_confirmation: password, 
                        manager: current_user, member_type: p_role, invited_to_type: nil, invited_to_id: nil)
        user.skip_confirmation!
        if user.save
          data = {success:{msg: "Invited new Super Admin", id: user.id.to_s, name: email}}
        else
          data = {failure:{msg: "Please check your email address.", element_id: "user_email"}}
        end

      elsif p_role == Role::ROLE[:vpd_admin]
        invited_to = {type: Vpd.name, id: vpd.id.to_s}
        user = User.new(email: email, password: password, password_confirmation: password, 
                        manager: current_user, member_type: p_role, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
        role = user.roles.build(rolify: vpd, role: p_role, vpd: vpd)
        user.skip_confirmation!
        if user.save
          role.save
          data = {success:{msg: "Invited new VPD Admin", id: user.id.to_s, name: email}}
        else
          data = {failure:{msg: "Please check your email address.", element_id: "user_email"}}
        end

      elsif p_role > Role::ROLE[:vpd_admin]  &&  p_role <= Role::ROLE[:trial_readonly]
        invited_to = {type: Trial.name, id: trial.id}
        user = User.new(email: email, password: password, password_confirmation: password, 
                        manager: current_user, member_type: p_role, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
        role = user.roles.build(rolify: trial, role: p_role, vpd: trial.vpd)
        user.skip_confirmation!
        if user.save
          role.save
          data = {success:{msg: "Invited new Trial Admin", id: user.id.to_s, name: email}}
        else
          data = {failure:{msg: "Failed to invite", element_id: "user_email"}}
        end

      elsif p_role > Role::ROLE[:trial_readonly]
        invited_to = {type: Site.name, id: site.id.to_s}
        user = User.new(email: email, password: password, password_confirmation: password, 
                        manager: current_user, member_type: p_role, invited_to_type: invited_to[:type], invited_to_id: invited_to[:id])
        role = user.roles.build(rolify: site, role: p_role, vpd: site.vpd)
        user.skip_confirmation!
        if user.save
          role.save
          data = {success:{msg: "Invited new Site User", id: user.id.to_s, name: email}}
        else
          data = {failure:{msg: "Failed to invite", element_id: "user_email"}}
        end
      end        
    end
    return data
  end

  # Public: Generates tooltip link
  def tooltip_link(title, placement="bottom", color="black", awesome_font="fa-info-circle")
    link_to("<i class='fa #{awesome_font} fa-fw'></i>".html_safe, "#", title: title.html_safe, data: {toggle: "tooltip", placement: placement}, style: "color:#{color};text-transform:none;").html_safe
  end

end
class UserDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user)
    @view = view
    @user = user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: users.count,
      iTotalDisplayRecords: users.total_entries,
      aaData: data.compact
    }
  end

  private

  def data
    users.map do |user| 
      last_login = user[:last_login]
      if user[:status] == 1
        if user[:invitation_sent_date].present?
          invitation_sent_date = "#{user[:invitation_sent_date].strftime("%d %b %Y")}<br/>".html_safe
          invite_text = "Resend Invite"
        else
          invitation_sent_date = ""
          invite_text = "Send Invite"
        end
        if user[:vpd].present?
          if user[:trial].present? 
            if user[:site].present?
              url = "/dashboard/site/#{user[:site]}/users/#{user[:role_id]}/send_invite"
            else 
              url = "/dashboard/trial/#{user[:trial]}/users/#{user[:role_id]}/send_invite"
            end
          else 
            url = "/dashboard/vpd/#{user[:vpd]}/users/#{user[:role_id]}/send_invite"
          end
          invite_link = link_to(invite_text, "javascript: send_invite('#{url}')")
          invite_link = "#{invitation_sent_date}#{invite_link}" unless invitation_sent_date.empty?
        elsif user[:vpd].nil?  &&  user[:status] == 1
          invite_link = link_to(invite_text, "javascript: send_invite('/dashboard//users/#{user[:user_id]}/send_invite')")
          invite_link = "#{invitation_sent_date}#{invite_link}" unless invitation_sent_date.empty?
        end
        last_login = last_login=="N/A" ? "" : last_login
      end

      if user[:role_id].present?
        status_id     = user[:role_id]
        status_class  = "Role"
        role_label    = link_to(user[:role_label], "/dashboard/users/#{user[:role_id]}/edit?type=0", remote: true, title: user[:role_title]).html_safe
      else
        status_id     = user[:user_id]
        status_class  = "User"
        role_label    = link_to(user[:role_label], "/dashboard/users/#{user[:user_id]}/edit?type=1", remote: true, title: user[:role_title]).html_safe
      end
      switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
          <button class='btn btn-xs #{user[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{status_id}' data-status='1' data-type='#{status_class}'>Yes</button>
          <button class='btn btn-xs #{user[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{status_id}' data-status='0' data-type='#{status_class}'>No</button>
        </div>".html_safe
      [     
        link_to(user[:email], "#profile", data:{url: "/dashboard/users/user_info?id=#{user[:user_id]}&type=ajax"}, class:"event-button") +"<br/>".html_safe+ user[:name],
        user[:vpd_name],
        user[:trial_id],
        user[:site_id],
        last_login,
        invite_link,
        role_label,
        switch_label,
        "row_super_#{user[:user_id]}"
      ]
    end
  end

  def users
    @users ||= fetch_users
  end

  def fetch_users
    status = params[:show_option].strip == "Include disabled"  ?  false : true
    admin_users = []
    roles = []
    if params[:sSearch].present?
      user_ids  = status ? User.where("(first_name LIKE :search_param OR last_name LIKE :search_param OR email LIKE :search_param) AND id != #{@user.id}", search_param: "%#{params[:sSearch]}%").map(&:id) 
                        : User.where("(first_name LIKE :search_param OR last_name LIKE :search_param OR email LIKE :search_param) AND id != #{@user.id} AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id) 
      if user_ids.present?
        admin_users = User.where(id: user_ids, member_type: Role::ROLE[:super_admin])

        vpd_ids   = Vpd.activated_vpds.map(&:id)
        or_case11 = vpd_ids.present? ? "(user_id IN (#{user_ids.join(",")}) AND rolify_id IN (#{vpd_ids.join(",")}))" : ""
        trial_ids = Trial.activated_trials.map(&:id)
        or_case12 = trial_ids.present? ? "(user_id IN (#{user_ids.join(",")}) AND rolify_id IN (#{trial_ids.join(",")}))" : ""
        site_ids  = Site.activated_sites.map(&:id)
        or_case13 = site_ids.present? ? "(user_id IN (#{user_ids.join(",")}) AND rolify_id IN (#{site_ids.join(",")}))" : ""

        or_case1 = or_case11 + ((or_case11.present? && or_case12.present?) ? " OR " : "") + or_case12
        or_case1 = or_case1 + ((or_case1.present? && or_case13.present?) ? " OR " : "") + or_case13
      else
        or_case1 = ""
      end

      vpd_ids  = Vpd.where("name LIKE :search_param AND status = 1", search_param: "%#{params[:sSearch]}").map(&:id)
      or_case2 = vpd_ids.present? ? "(rolify_type = 'Vpd' AND rolify_id IN (#{vpd_ids.join(",")}))" : ""

      trial_ids = Trial.where("(trial_id LIKE :search_param #{vpd_ids.present? ? "OR vpd_id IN (#{vpd_ids.join(",")})" : ""}) AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id)
      or_case3  = trial_ids.present? ? "(rolify_type = 'Trial' AND rolify_id IN (#{trial_ids.join(",")}))" : ""

      site_ids = Site.where("(site_id LIKE :search_param #{trial_ids.present? ? " OR trial_id IN (#{trial_ids.join(",")})" : ""}) AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id)
      or_case4 = site_ids.present? ? "(rolify_type = 'Site' AND rolify_id IN (#{site_ids.join(",")}))" : ""

      or_case = or_case1 + ((or_case1.present? && or_case2.present?) ? " OR " : "") + or_case2
      or_case = or_case + ((or_case.present? && or_case3.present?) ? " OR " : "") + or_case3
      or_case = or_case + ((or_case.present? && or_case4.present?) ? " OR " : "") + or_case4

      roles = status ? Role.where(or_case) : Role.where("(#{or_case}) AND status = 1") if or_case.present?
    else
      user_ids  = nil
      admin_users = status ? User.where("id != #{@user.id} AND member_type = #{Role::ROLE[:super_admin]}")
                          : User.where("id != #{@user.id} AND member_type = #{Role::ROLE[:super_admin]} AND status = 1")

      vpd_ids  = Vpd.activated_vpds.map(&:id)
      or_case1 = vpd_ids.present? ? "(rolify_type = 'Vpd' AND rolify_id IN (#{vpd_ids.join(",")}))" : ""

      trial_ids = Trial.activated_trials.map(&:id)
      or_case2 = trial_ids.present? ? "(rolify_type = 'Trial' AND rolify_id IN (#{trial_ids.join(",")}))" : ""

      site_ids  = Site.activated_sites.map(&:id)
      or_case3 = site_ids.present? ? "(rolify_type = 'Site' AND rolify_id IN (#{site_ids.join(",")}))" : ""

      or_case = or_case1 + ((or_case1.present? && or_case2.present?) ? " OR " : "") + or_case2
      or_case = or_case + ((or_case.present? && or_case3.present?) ? " OR " : "") + or_case3

      roles = status ? Role.where(or_case) : Role.where("(#{or_case}) AND status = 1") if or_case.present?
    end

    users = admin_users.map do |user|
      role_label = user.member_type_label
      {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, status: user.status,
      vpd: nil, vpd_name: '', trial: nil, trial_id: '', site: nil, site_id: '', role_title: role_label[0], role_label: role_label[1]}
    end

    role_users = roles.map do |role|
      user = role.user
      role_label = role.role_label
      e = {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, invitation_sent_date: role.invitation_sent_date, role_id: role.id.to_s, status: role.status}
      if role.rolify_type == "Vpd"
        vpd = role.rolify
        e.merge(vpd: vpd.id.to_s, vpd_name: vpd.name, trial: nil, trial_id: '', site: nil, site_id: '', role_title: role_label[0], role_label: role_label[1])
      elsif role.rolify_type == "Trial"
        trial = role.rolify
        vpd   = trial.vpd
        e.merge(vpd: vpd.id.to_s, vpd_name: vpd.name, trial: trial.id.to_s, trial_id: trial.trial_id, site: nil, site_id: '', role_title: role_label[0], role_label: role_label[1])
      elsif role.rolify_type == "Site"
        site  = role.rolify
        trial = site.trial
        vpd   = trial.vpd
        e.merge(vpd: vpd.id.to_s, vpd_name: vpd.name, trial: trial.id.to_s, trial_id: trial.trial_id, site: site.id.to_s, site_id: site.site_id, role_title: role_label[0], role_label: role_label[1])
      end
    end

    users.concat(role_users)

    users = sort_array_with_data(users, sort_column, sort_direction)
    users.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[last_name vpd_name trial_id site_id last_login invitation_sent_date]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
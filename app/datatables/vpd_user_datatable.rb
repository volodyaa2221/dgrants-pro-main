class VpdUserDatatable
  include DatatableHelper
  
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd)
    @view   = view
    @user   = user
    @vpd    = vpd
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
    vpd_id    = @vpd.id.to_s
    vpd_name  = @vpd.name

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
        if user[:trial].present? 
          if user[:site].present?
            url = "/dashboard/site/#{user[:site]}/users/#{user[:role_id]}/send_invite"
          else 
            url = "/dashboard/trial/#{user[:trial]}/users/#{user[:role_id]}/send_invite"
          end
        else 
          url = "/dashboard/vpd/#{vpd_id}/users/#{user[:role_id]}/send_invite"
        end
        invite_link = link_to(invite_text, "javascript: send_invite('#{url}')")
        invite_link = "#{invitation_sent_date}#{invite_link}" unless invitation_sent_date.empty?
        last_login  = last_login=="N/A" ? "" : last_login
      end

      role_label = link_to(user[:role_label], "/dashboard/vpd/#{vpd_id}/users/#{user[:role_id]}/edit", remote: true, title: user[:role_title]).html_safe
      switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
          <button class='btn btn-xs #{user[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{user[:role_id]}' data-status='1' data-type='Role'>Yes</button>
          <button class='btn btn-xs #{user[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{user[:role_id]}' data-status='0' data-type='Role'>No</button>
        </div>".html_safe

      [
        "<a href='mailto:#{user[:email]}'>#{user[:email]}</a><br/>".html_safe + user[:name],
        vpd_name,
        user[:trial_id],
        user[:site_id],
        last_login,
        invite_link,
        role_label,
        switch_label,
        "row_#{user[:role_id]}"
      ]
    end    
  end

  def users
    @users ||= fetch_users
  end

  def fetch_users
    require 'will_paginate/array'

    status = params[:show_option].strip == "Include disabled"  ?  false : true
    user_ids = params[:sSearch].present? ? User.where("first_name LIKE :search_param OR last_name LIKE :search_param OR email LIKE :search_param", search_param: "%#{params[:sSearch]}%").map(&:id) : nil

    vpd_admin_roles = []
    if params[:sSearch].present?
      if user_ids.present?
        where_case = "rolify_type = 'Vpd' AND rolify_id = #{@vpd.id} AND user_id != #{@user.id} AND user_id IN (#{user_ids.join(",")})"
        vpd_admin_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    else
      where_case = "rolify_type = 'Vpd' AND rolify_id = #{@vpd.id} AND user_id != #{@user.id}"
      vpd_admin_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
    end
    users = vpd_admin_roles.map do |role|
      user  = role.user
      role_label = role.role_label
      {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, status: role.status,
       role_id: role.id.to_s, role_title: role_label[0], role_label: role_label[1], invitation_sent_date: role.invitation_sent_date,
       trial: nil, trial_id: '', site: nil, site_id: ''}
    end

    trial_roles = []
    if params[:sSearch].present?
      trial_ids = Trial.where("trial_id LIKE :search_param AND vpd_id = #{@vpd.id} AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id)
      or_case1 = trial_ids.present? ? "rolify_id IN (#{trial_ids.join(",")})" : ""
      trial_ids = Trial.where(vpd: @vpd, status: 1).map(&:id)
      or_case2 = user_ids.present? && trial_ids.present? ? "(user_id IN (#{user_ids.join(",")}) AND rolify_id IN (#{trial_ids.join(",")}))" : ""
      or_case = or_case1 + ((or_case1.present? && or_case2.present?) ? " OR " : "") + or_case2
      if or_case.present?
        where_case = "(#{or_case}) AND rolify_type = 'Trial' AND user_id != #{@user.id}"
        trial_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    else
      trial_ids = Trial.where(vpd: @vpd, status: 1).map(&:id)
      if trial_ids.present?
        where_case = "rolify_type = 'Trial' AND rolify_id IN (#{trial_ids.join(",")}) AND user_id != #{@user.id}"
        trial_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    end
    trial_roles.each do |role|
      trial = role.rolify
      user  = role.user
      role_label = role.role_label
      users << {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, status: role.status,
                role_id: role.id.to_s, role_title: role_label[0], role_label: role_label[1], invitation_sent_date: role.invitation_sent_date,
                trial: trial.id.to_s, trial_id: trial.trial_id, site: nil, site_id: ''}
    end

    site_roles = []
    if params[:sSearch].present?
      site_ids = Site.where("site_id LIKE :search_param AND vpd_id = #{@vpd.id} AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id)
      or_case1 = site_ids.present? ? "rolify_id IN (#{site_ids.join(",")})" : ""

      site_ids = Site.where(vpd: @vpd, status: 1).map(&:id)
      or_case2 = user_ids.present? && site_ids.present? ? "(user_id IN (#{user_ids.join(",")}) AND rolify_id IN (#{site_ids.join(",")}))" : ""

      trial_ids = Trial.where("trial_id LIKE :search_param AND vpd_id = #{@vpd.id} AND status = 1", search_param: "%#{params[:sSearch]}%").map(&:id)
      site_ids = trial_ids.present? ? Site.where(trial_id: trial_ids, status: 1).map(&:id) : []
      or_case3 = site_ids.present? ? "rolify_id IN (#{site_ids.join(",")})" : ""

      or_case = or_case1 + ((or_case1.present? && or_case2.present?) ? " OR " : "") + or_case2
      or_case = or_case + ((or_case.present? && or_case3.present?) ? " OR " : "") + or_case3
      if or_case.present?
        where_case = "(#{or_case}) AND rolify_type = 'Site' AND user_id != #{@user.id}"
        site_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    else
      site_ids = Site.includes(:trial).where("trials.status" => 1, vpd: @vpd).map(&:id)
      if site_ids.present?
        where_case = "rolify_type = 'Site' AND rolify_id IN (#{site_ids.join(",")}) AND user_id != #{@user.id}"
        site_roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    end
    site_roles.each do |role|
      site = role.rolify
      user = role.user
      role_label = role.role_label
      users << {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, status: role.status,
                role_id: role.id.to_s, role_title: role_label[0], role_label: role_label[1], invitation_sent_date: role.invitation_sent_date,
                trial: site.trial.id.to_s, trial_id: site.trial.trial_id, site: site.id.to_s, site_id: site.site_id}
    end

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
    columns = %w[last_name vpd trial_id site_id last_login invitation_sent_date]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
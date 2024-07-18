class SiteUserDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, site)
    @view = view
    @user = user
    @site = site
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
    vpd_id    = @site.vpd.id.to_s
    vpd_name  = @site.vpd.name
    trial     = @site.trial.id.to_s
    trial_id  = @site.trial.trial_id
    site      = @site.id.to_s
    site_id   = @site.site_id
    editable  = @user.site_editable?(@site)

    users.map do |user|
      last_login = user[:last_login]
      if editable  &&  user[:status] == 1
        if user[:invitation_sent_date].present?
          invitation_sent_date = "#{user[:invitation_sent_date].strftime("%d %b %Y")}<br/>".html_safe
          invite_text = "Resend Invite"
        else
          invitation_sent_date = ""
          invite_text = "Send Invite"
        end
        url = "/dashboard/site/#{site}/users/#{user[:role_id]}/send_invite"
        invite_link = link_to(invite_text, "javascript: send_invite('#{url}')")
        invite_link = "#{invitation_sent_date}#{invite_link}" unless invitation_sent_date.empty?
        last_login  = last_login=="N/A" ? "" : last_login
      end

      role_label = editable ? link_to(user[:role_label], "/dashboard/site/#{site}/users/#{user[:role_id]}/edit", remote: true, title: user[:role_title]).html_safe :
                  "<p title='#{user[:role_title]}'>#{user[:role_label]}</p>".html_safe
      switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
                      <button class='btn btn-xs #{user[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{user[:role_id]}' data-status='1' data-type='Role'}'>Yes</button>
                      <button class='btn btn-xs #{user[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{user[:role_id]}' data-status='0' data-type='Role'>No</button>
                    </div>".html_safe

      [
        "<a href='mailto:#{user[:email]}'>#{user[:email]}</a><br/>".html_safe + user[:name],
        vpd_name,
        trial_id,
        site_id,
        last_login,
        invite_link,
        role_label,
        editable ? switch_label : user[:status_label],       
        "row_#{user[:role_id]}"
      ]
    end
  end

  def users
    @users ||= fetch_users
  end

  def fetch_users
    status = params[:show_option].strip == "Include disabled" ? false : true

    roles = []
    if params[:sSearch].present?
      user_ids = User.where("first_name LIKE :search_param OR last_name LIKE :search_param OR email LIKE :search_param", search_param: "%#{params[:sSearch]}%").map(&:id)
      if user_ids.present?
        where_case = "rolify_type = 'Site' AND rolify_id = #{@site.id} AND user_id != #{@user.id} AND user_id IN (#{user_ids.join(",")})"
        roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
      end
    else
      where_case = "rolify_type = 'Site' AND rolify_id = #{@site.id} AND user_id != #{@user.id}"
      roles = status ? Role.where(where_case) : Role.where("#{where_case} AND status = 1")
    end

    users = roles.map do |role|
      user = role.user
      role_label = role.role_label
      role.status = 0 if role.status.nil?
      {user_id: user.id.to_s, email: user.email, name: user.name, last_name: user.last_name, last_login: user.last_login, status: role.status,
       role_id: role.id.to_s, role_title: role_label[0], role_label: role_label[1], invitation_sent_date: role.invitation_sent_date, status_label: role.status_label}
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

  def columns
  end

  def sort_column
    columns = %w[last_name vpd trial site last_login invitation_sent_date]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
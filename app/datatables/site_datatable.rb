class SiteDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user)
    @view = view
    @user = user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: sites.count,
      iTotalDisplayRecords: sites.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    color_cls1 = ["circle-red", "circle-red", "circle-green", "circle-green"]
    color_cls2 = ["circle-red", "circle-red", "circle-green"]
    color_cls3 = ["circle-red", "circle-green"]

    sites.map do |e|
      site_admins = []
      e[:site].site_admins.each_with_index do |site_admin, i|
        prefix = i > 0 ? "&nbsp;"*6 : ''
        if site_admin.name.blank?
          site_admins << "#{prefix.html_safe}<a href='mailto:#{site_admin.email}'>#{site_admin.email}</a>"
        else
          site_admins << "#{prefix.html_safe}<a href='mailto:#{site_admin.email}'>#{site_admin.name}</a>"
        end
      end
      pi_name = (pi_name=e[:site].pi_name).present? ? "<br/><label style='color:black;margin-bottom:-30px;'><b>PI:</b></label> #{e[:site].pi_name}" : ""
      site_admins = site_admins.count > 0 ? "<label style='color:red'>SA:</label> " + site_admins.join("<br/>") : "<label style='color:red'>SA: none</label>"
      switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
                        <button class='btn btn-xs #{e[:site].status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{e[:site].id.to_s}' data-status='1' data-type='#{e[:site].class.name}'>Yes</button>
                        <button class='btn btn-xs #{e[:site].status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{e[:site].id.to_s}' data-status='0' data-type='#{e[:site].class.name}'>No</button>
                      </div>".html_safe
      status_label = e[:site].status == 1 ? "Active" : "Disabled"

      site_name_label = "<a href='/dashboard/site/sites/#{e[:site].id.to_s}/dashboard' title='#{e[:site].name}'>#{e[:site].name.truncate(50)}</a>"
      site_name_label += ((e[:site].city.present? && e[:site].state.present?) ? "<br/>#{e[:site].city.truncate(20)}/#{e[:site].state.truncate(30)}": "") + pi_name + "<br/>#{site_admins}"

      symbol = e[:site].site_schedule.vpd_currency.symbol
      usd_amount = amount = 0
      Invoice.where(site: e[:site], status: [Invoice::STATUS[:paid_offline], Invoice::STATUS[:successful]]).each do |invoice|
        usd_amount += invoice.amount * invoice.usd_rate
        amount     += invoice.amount
      end

      color1 = color_cls1[e[:payment_verified]]
      color2 = color_cls2[e[:budget_status]]
      color3 = color_cls3[e[:passthrough_status]]
      [
        e[:site].site_id,
        site_name_label.html_safe,
        e[:site].country_name,
        e[:site].users.count,
        "$ #{usd_amount.round(2)}<br/>#{symbol} #{amount.round(2)}",
        status_label_by_color(color2, @view.dashboard_site_schedule_path(e[:site])),
        # status_label_by_color(color1, @view.edit_payment_info_dashboard_site_payment_infos_path(e[:site])),
        status_label_by_color(color3, @view.dashboard_site_passthroughs_path(e[:site])),
        @user.site_editable?(e[:site]) ? switch_label : status_label,
        "row_"+e[:site].id.to_s
      ]
    end  
  end

  def sites
    @sites ||= fetch_sites
  end

  def fetch_sites
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    trial = Trial.find(params[:id])
    where_case = "(site_id LIKE :search_param OR name LIKE :search_param OR city LIKE :search_param OR state LIKE :search_param "\
                 "OR address LIKE :search_param OR zip_code LIKE :search_param OR country_name LIKE :search_param) AND trial_id = #{trial.id}"
    unless @user.trial_level_user?(trial)
      if params[:sSearch].present?
        sites = status ? @user.sites.where(where_case, search_param: "%#{params[:sSearch]}%")
                       : @user.sites.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
      else 
        sites = status ? @user.sites.where(trial: trial) : @user.sites.where(trial: trial, status: 1)
      end
    else
      if params[:sSearch].present?
        sites = status ? Site.where(where_case, search_param: "%#{params[:sSearch]}%")
                       : Site.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
      else
        sites = status ? trial.sites : Site.where(trial: trial, status: 1)
      end
    end

    sites = sites.map do |site|
      {
        site: site, site_id: site.site_id, 
        country_name: site.country_name, 
        payment_verified: site.payment_verified, 
        budget_status: site.site_schedule.schedule_status, 
        passthrough_status: (Passthrough.has_pending?(site) ? 0 : 1)
      }
    end

    sites = sort_array_with_data(sites, sort_column, sort_direction)
    sites.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    # columns = %w[site_id country_name budget_status payment_verified passthrough_status]
    columns = %w[site_id country_name budget_status passthrough_status]
    index = params[:iSortCol_0].to_i
    index -= 3 if index > 2
    columns[index]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def status_label_by_color(color_class, link="#")
    if color_class.include?("green")
      info_tag = "<i class='fa fa-check' style='color:green;'></i>"
    else
      color = color_class.gsub("circle-", "")
      info_tag = "<i class='fa fa-warning' style='color:#{color};'></i>"
    end
    "<a href='#{link}' target='_blank'>#{info_tag}</a>".html_safe
  end
end
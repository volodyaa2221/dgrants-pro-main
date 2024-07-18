class VpdDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user)
    @view = view
    @user = user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: vpds.count,
      iTotalDisplayRecords: vpds.total_entries,
      aaData: data.compact
    }
  end

private
  def data    
    vpds.map do |vpd|
      [
        link_to(vpd[:name], "/dashboard/vpd/vpds/#{vpd[:id]}/trials"),
        vpd[:trials]>0 ? vpd[:trials] : nil,
        vpd[:sites]>0 ? vpd[:sites] : nil,
        vpd[:users]>0 ? vpd[:users] : nil,
        link_to("Edit", "/dashboard/vpd/vpds/#{vpd[:id]}/edit", remote: true),
        "row_" + vpd[:id]
      ]
    end  
  end

  def vpds
    @vpds ||= fetch_vpds
  end

  def fetch_vpds
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    vpds = []
    if params[:sSearch].present?
      where_case = "name LIKE :search_param"
      vpds = status ? Vpd.where(where_case, search_param: "%#{params[:sSearch]}%") 
                    : Vpd.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
    else
      vpds = status ? Vpd.all : Vpd.activated_vpds
    end

    vpds = vpds.map do |vpd|
      trials_count    = vpd.activated_trials.count
      sites_count     = vpd.activated_sites.count   
      vpd_users_count = vpd.vpd_admins.count + vpd.trial_site_users.count
      {id: vpd.id.to_s, name: vpd.name, trials: trials_count, sites: sites_count, users: vpd_users_count}
    end

    if sort_column == "name"
      vpds = sort_direction=="asc" ? vpds.sort_by{|e| e[:name].downcase} : vpds.sort{|r, u| u[:name].downcase <=> r[:name].downcase}
    elsif sort_column == "trials" 
      vpds = sort_direction=="asc" ? vpds.sort_by{|e| e[:trials]} : vpds.sort_by{|e| -e[:trials]}
    elsif sort_column == "sites"
      vpds = sort_direction=="asc" ? vpds.sort_by{|e| e[:sites]} : vpds.sort_by{|e| -e[:sites]}
    elsif sort_column == "users"      
      vpds = sort_direction=="asc" ? vpds.sort_by{|e| e[:users]} : vpds.sort_by{|e| -e[:users]}
    end

    vpds.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name trials sites users]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
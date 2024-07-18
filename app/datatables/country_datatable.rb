class CountryDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd=nil)
    @view   = view
    @user   = user
    @vpd    = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: countries.count,
      iTotalDisplayRecords: countries.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    countries.map do |country|
      url = @vpd.present? ? "/dashboard/vpd/#{@vpd.id.to_s}/countries/#{country[:id]}/update_status" : "/dashboard/update_status"
      [
        country[:name],
        country[:trials]>0 ? country[:trials] : '',
        country[:sites]>0 ? country[:sites] : '',
        "<div class='btn-group btn-toggle' data-update-url='#{url}'>
            <button class='btn btn-xs #{country[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{country[:id].to_s}' data-status='1' data-type='#{country[:class_name]}'>Yes</button>
            <button class='btn btn-xs #{country[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{country[:id].to_s}' data-status='0' data-type='#{country[:class_name]}'>No</button>
          </div>".html_safe,
        "row_"+country[:id].to_s
      ]
    end
  end

  def countries
    @countries ||= fetch_countries
  end

  def fetch_countries
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    countries = []
    if @vpd.present?
      country_ids = @vpd.vpd_countries.map(&:country_id)
      if params[:sSearch].present?
        where_case = "name LIKE :search_param AND vpd_id = #{@vpd.id}"
        countries = status ? VpdCountry.where(where_case, search_param: "%#{params[:sSearch]}%") 
                           : VpdCountry.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
      else 
        countries = status ? @vpd.vpd_countries : VpdCountry.where(vpd: @vpd, status: 1)
      end
      countries   = countries.map do |country|
        trials_count  = country.trials.count
        sites_count   = Site.where(vpd_country: country, status: 1).count
        {id: country.id.to_s, name: country.name, trials: trials_count, sites: sites_count, status: country.status, class_name: country.class.name}
      end
      if status
        temp = []
        where_case = country_ids.present? ? "id NOT IN (#{country_ids.join(",")}) AND status = 1" : "status = 1"
        temp = params[:sSearch].present? ? Country.where("#{where_case} AND name LIKE :search_param", search_param: "%#{params[:sSearch]}%") 
                                         : Country.where(where_case)
        temp = temp.map {|country| {id: country.id.to_s, name: country.name, trials: 0, sites: 0, status: 0, class_name: country.class.name}}
        countries = countries.concat(temp)
      end
    else
      if params[:sSearch].present?
        countries = status ? Country.where("name LIKE :search_param", search_param: "%#{params[:sSearch]}%") 
                           : Country.where("name LIKE :search_param AND status = 1", search_param: "%#{params[:sSearch]}%")
      else
        countries = status ? Country.all : Country.activated_countries
      end      
      countries = countries.map do |country|
        trials_count  = country.trials.count
        sites_count   = Site.where(country: country, status: 1).count
        {id: country.id.to_s, name: country.name, trials: trials_count, sites: sites_count, status: country.status, class_name: country.class.name}
      end
    end

    if sort_column == "name"
      countries = sort_direction=="asc" ? countries.sort_by{|e| e[:name].downcase} : countries.sort{|r, u| u[:name].downcase <=> r[:name].downcase}
    elsif sort_column == "trials" 
      countries = sort_direction=="asc" ? countries.sort_by{|e| e[:trials]} : countries.sort_by{|e| -e[:trials]}
    elsif sort_column == "sites"      
      countries = sort_direction=="asc" ? countries.sort_by{|e| e[:sites]} : countries.sort_by{|e| -e[:sites]}
    end

    countries.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name trials sites]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
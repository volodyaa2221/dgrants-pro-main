class SponsorDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd=nil)
    @view = view
    @user = user
    @vpd = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: sponsors.count,
      iTotalDisplayRecords: sponsors.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    sponsors.map do |sponsor|
      url = @vpd.present? ? "/dashboard/vpd/#{@vpd.id.to_s}/sponsors/#{sponsor[:id]}/update_status" : "/dashboard/update_status"
      [
        @vpd.present? ? sponsor[:name] : link_to(sponsor[:name], "/dashboard/sponsors/#{sponsor[:id].to_s}/edit", remote: true),
        sponsor[:trials]>0 ? sponsor[:trials] : '',
        sponsor[:sites]>0 ? sponsor[:sites] : '',
        "<div class='btn-group btn-toggle' data-update-url='#{url}'>
            <button class='btn btn-xs #{sponsor[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{sponsor[:id].to_s}' data-status='1' data-type='#{sponsor[:class_name]}'>Yes</button>
            <button class='btn btn-xs #{sponsor[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{sponsor[:id].to_s}' data-status='0' data-type='#{sponsor[:class_name]}'>No</button>
          </div>".html_safe,
        "row_"+sponsor[:id].to_s
      ]
    end  
  end

  def sponsors
    @sponsors ||= fetch_sponsors
  end

  def fetch_sponsors
    @include_disabled = params[:show_option].strip == "Include disabled" ? false : true

    if @vpd.present?
      VpdSponsor.select("u.*").from(sql2).order(order_clause).paginate(page: page, :per_page => per_page)
    else
      Sponsor.select("u.*").from("(#{sql1}) as u").order(order_clause).paginate(page: page, :per_page => per_page)
    end
  end

  def sql1
    "#{select_clause1} "\
    "#{join_clause1} "\
    "#{where_clause1} "\
    "GROUP BY sp.id "
  end

  def select_clause1
    class_name = @vpd.present? ? "VpdSponsor" : "Sponsor"
    table_name = @vpd.present? ? "vpd_sponsors" : "sponsors"
    "SELECT "\
      "sp.name as `name`, "\
      "COUNT(DISTINCT t.id) as `trials`, "\
      "COUNT(DISTINCT s.id) as `sites`, "\
      "sp.id, '#{class_name}' as `class_name`, sp.status "\
    "FROM #{table_name} sp "
  end

  def join_clause1
    field_name = @vpd.present? ? "vpd_sponsor_id" : "sponsor_id"
    "LEFT JOIN trials as t ON sp.id = t.#{field_name} AND t.status = 1 "\
    "LEFT JOIN sites as s ON s.trial_id = t.id AND s.status = 1 "
  end

  def where_clause1
    clauses = []
    clauses << "sp.vpd_id = #{@vpd.id}" if @vpd.present?
    clauses << keyword_search_clause1 if params[:sSearch].present?
    clauses << "sp.status = 1" unless @include_disabled
    clauses.count > 0 ? "WHERE #{clauses.join(" AND ")} " : nil
  end

  def keyword_search_clause1
    keyword = "'%#{params[:sSearch]}%'"
    "sp.name LIKE #{keyword}"
  end

  def sql2
    query = 
    "SELECT "\
      "sp2.name as `name`, "\
      "0 as `trials_count`, "\
      "0 as `sites_count`, "\
      "sp2.id, 'Sponsor' as `class_name`, 0 as status "\
    "FROM sponsors sp2 "\
    "#{where_clause2} "
    
    @include_disabled ? "(#{sql1} UNION ALL #{query}) as u" : "(#{sql1}) as u"
  end

  def where_clause2
    clauses = []
    clauses << "id NOT IN (SELECT sponsor_id FROM vpd_sponsors vsp WHERE vsp.vpd_id=#{@vpd.id})"
    clauses << keyword_search_clause2 if params[:sSearch].present?
    clauses << "sp2.status = 1"
    "WHERE #{clauses.join(" AND ")} "
  end

  def keyword_search_clause2
    keyword = "'%#{params[:sSearch]}%'"
    "sp2.name LIKE #{keyword}"
  end

  def order_clause
    "#{sort_column} #{sort_direction}"
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name trials sites status]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
class LedgerCategoryDatatable
    delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd)
    @view = view
    @user = user
    @vpd  = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: categories.count,
      iTotalDisplayRecords: categories.total_entries,
      aaData: data.compact
    }
  end

private
  def data    
    categories.map do |category|
      switch_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
                        <button class='btn btn-xs #{category.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{category.id.to_s}' data-status='1' data-type='#{category.class.name}'>Yes</button>
                        <button class='btn btn-xs #{category.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{category.id.to_s}' data-status='0' data-type='#{category.class.name}'>No</button>
                      </div>".html_safe
      [
        link_to(category.name, "/dashboard/vpd/#{@vpd.id.to_s}/ledger_categories/#{category.id.to_s}/edit", remote: true).html_safe,
        switch_label,
        "row_" + category.id.to_s
      ]
    end  
  end

  def categories
    @categories ||= fetch_categories
  end

  def fetch_categories
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    if params[:sSearch].present?
      where_case = "vpd_id = #{@vpd.id} AND name LIKE :search_param"
      categories = status ? VpdLedgerCategory.where(where_case, search_param: "%#{params[:sSearch]}%")
                          : VpdLedgerCategory.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
    else
      categories = status ? VpdLedgerCategory.where(vpd: @vpd) : VpdLedgerCategory.where(vpd: @vpd, status: 1)
    end

    categories.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
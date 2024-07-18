class VpdMailtemplateDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, vpd)
    @view   = view
    @vpd    = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: mailtemplates.count,
      iTotalDisplayRecords: mailtemplates.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    mailtemplates.map do |mailtemplate|
      [
        link_to(mailtemplate.type_label, "/dashboard/vpd/#{@vpd.id.to_s}/mail_templates/#{mailtemplate.id.to_s}/edit", remote: true),
        mailtemplate.subject,
        "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
            <button class='btn btn-xs #{mailtemplate.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{mailtemplate.id.to_s}' data-status='1' data-type='#{mailtemplate.class.name}'>Yes</button>
            <button class='btn btn-xs #{mailtemplate.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{mailtemplate.id.to_s}' data-status='0' data-type='#{mailtemplate.class.name}'>No</button>
          </div>".html_safe,        
        "row_#{mailtemplate.id.to_s}"
      ]
    end  
  end

  def mailtemplates
    @mailtemplates ||= fetch_mailtemplates
  end

  def fetch_mailtemplates
    status = params[:show_option].strip == "Include disabled"  ?  false : true
    search = params[:sSearch].present? ? params[:sSearch] : nil

    if search.present?
      where_case = "subject LIKE :search_param AND vpd_id=#{@vpd.id}"
      mailtemplates = status ? VpdMailTemplate.where(where_case, search_param: "%#{params[:sSearch]}%")
                             : VpdMailTemplate.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
    else
      mailtemplates = status ? @vpd.vpd_mail_templates : VpdMailTemplate.where(vpd: @vpd, status: 1)
    end
    
    mailtemplates.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name subject]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
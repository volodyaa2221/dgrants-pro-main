class VpdApproverDatatable
    delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd, type)
    @view = view
    @user = user
    @vpd  = vpd
    @type = type
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: approvers.count,
      iTotalDisplayRecords: approvers.total_entries,
      aaData: data.compact
    }
  end

private
  def data    
    approvers.map do |approver|
      [
        approver[:name],
        "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
            <button class='btn btn-xs #{approver[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{approver[:id]}' data-status='1' data-type='VpdApprover'>Yes</button>
            <button class='btn btn-xs #{approver[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{approver[:id]}' data-status='0' data-type='VpdApprover'>No</button>
          </div>".html_safe,        
        "row_" + approver[:id]
      ]
    end  
  end

  def approvers
    @approvers ||= fetch_approvers
  end

  def fetch_approvers
    vpd_approvers = VpdApprover.where(vpd: @vpd, type: @type).order(created_at: :asc).map do |vpd_approver|
      user = vpd_approver.user
      {name: "#{user.email} / #{user.name}", status: vpd_approver.status, id: vpd_approver.id.to_s}
    end
    vpd_approvers.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 1000
  end
end
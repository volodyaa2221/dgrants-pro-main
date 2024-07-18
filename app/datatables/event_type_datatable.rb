class EventTypeDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, object, type)
    @view   = view
    @user   = user
    @object = object
    @type   = type
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: events.count,
      iTotalDisplayRecords: events.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    if @object.class.name == "Vpd"
      editable = true
    elsif @object.class.name == "Trial"
      editable = @user.trial_editable?(@object)
    end

    events.map do |event|
      event_editable = @object.class.name=="Vpd" ? true : event.editable
      if event_editable  &&  @object.class.name == "Vpd"
        link = "/dashboard/vpd/#{@object.id.to_s}/events/#{event.id.to_s}/edit"
      elsif event_editable  &&  @object.class.name == "Trial" 
        link = "/dashboard/trial/#{@object.id.to_s}/events/#{event.id.to_s}/edit"
      end

      status_label = "<div class='btn-group btn-toggle' data-update-url='/dashboard/update_status'>
                        <button class='btn btn-xs #{event.status==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{event.id.to_s}' data-status='1' data-type='#{event.class.name}'>Yes</button>
                        <button class='btn btn-xs #{event.status==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{event.id.to_s}' data-status='0' data-type='#{event.class.name}'>No</button>
                      </div>".html_safe
      dependency = event.dependency.present? ? "#{event.dependency.event_id}+#{event.days}d" : ''
      [ 
        event.order.to_i + 1, # event.order+1,
        !editable ? (event.event_id) : ((event.event_id=="CONTRACT" || event.event_id=="CONSENT" || !event_editable) ? event.event_id : link_to(event.event_id, link, remote: true)),
        event.description,
        dependency,
        !editable ? event.status_label : ((event.event_id=="CONTRACT" || event.event_id=="CONSENT" || !event_editable) ? event.status_label : status_label),
        "row_"+event.id.to_s
      ]
    end
  end

  def events
    @events ||= fetch_events
  end

  def fetch_events
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    target_model = "#{@object.class.name}Event".constantize # it can be VpdEvent/TrialEvent according to the object class name
    reference_field = "#{@object.class.name.downcase}_id"   # it can be vpd_id/trial_id

    if params[:sSearch].present?
      where_case = "(event_id LIKE :search_param OR description LIKE :search_param) AND #{reference_field} = #{@object.id} AND type = #{@type}"
      events = status ? target_model.where(where_case, search_param: "%#{params[:sSearch]}%").order(order: :asc)
                      : target_model.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%").order(order: :asc)
    else 
      events = status ? target_model.where(reference_field => @object, type: @type).order(order: :asc) 
                      : target_model.where(reference_field => @object, type: @type, status: 1).order(order: :asc)
    end
        
    events.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 50
  end

  def sort_column
    columns = %w[event_id description dependency]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def sort_element(val1, val2)
    if val1.dependency.nil? && val2.dependency.nil?
      (val1.created_at < val2.created_at) ? -1 : 1
    elsif val1.dependency.nil? && val2.dependency.present?
      -1
    elsif val1.dependency.present? && val2.dependency.nil?
      1
    elsif val1.dependency.present? && val2.dependency.present?
      (val1.days < val2.days) ? -1 : 1
    end
  end
end
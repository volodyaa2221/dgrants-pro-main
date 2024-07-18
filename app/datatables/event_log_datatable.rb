class EventLogDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, object)
    @view   = view
    @user   = user
    @object = object
    @type   = @object.class.name == "Trial"
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
    editable  = @type ? @user.trial_editable?(@object) : (@user.trial_editable?(@object.trial) || @object.trial_associate?(@user))
    object_id = @object.id.to_s

    events.map do |event|
      status_label = event.status==1 ? link_to("<i class='fa fa-trash fa-lg'></i>".html_safe, "javascript: delete_log('#{event.id.to_s}')") : "Deleted"
      approved_label = approved_label = event.approved ? "Yes" : "No"
      if event.status==1 && editable && !event.approved
        url = "/dashboard/trial/#{@type ? object_id : @object.trial.id}/site_events/#{event.id.to_s}/update_status" 
        approved_label = "<div class='btn-group btn-toggle-event' data-update-url='#{url}'>"\
                  "<button class='btn btn-xs #{event.approved ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{event.id.to_s}' data-approved='1'>Yes</button>"\
                  "<button class='btn btn-xs #{!event.approved ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{event.id.to_s}' data-approved='0'>No</button>"\
                "</div>".html_safe
      end
      event_id = @type ? (editable ? link_to(event.event_id_label, "/dashboard/trial/#{object_id}/site_events/#{event.id.to_s}/edit", remote: true) : event.event_id_label)
                       : editable ? link_to(event.event_id_label, "/dashboard/site/#{object_id}/events/#{event.id.to_s}/edit", remote: true) : event.event_id_label
      e = [ 
        event.event_log_id,
        event.happened_at.present? ? event.happened_at.strftime("%m/%d/%Y") : '',
        event_id,
        "<p title='#{event.description}'>#{event.description.truncate(50)}</p>",
        "<p title='logged by #{event.author}'>#{event.source}</p>",
        editable ? status_label : event.status_label,
        approved_label,
        "row_"+event.id.to_s
      ]
      e.unshift(event.site.site_id) if @type
      e
    end
  end

  def events
    @events ||= fetch_events
  end

  def fetch_events
    status = params[:show_option].strip == "Include deleted"  ?  false : true

    events = []
    if params[:sSearch].present?
      where_case = "(event_id LIKE :search_param OR patient_id LIKE :search_param OR description LIKE :search_param OR source LIKE :search_param"\
                   " OR happened_at_text LIKE :search_param) AND source != '#{SiteEvent::SOURCE[:forecasting]}'"
      if @type
        site_ids = Site.where(trial: @object, status: 1).map(&:id)
        if site_ids.present?
          events = status ? SiteEvent.where("#{where_case} AND site_id IN (#{site_ids.join(",")})", search_param: "%#{params[:sSearch]}%") 
                          : SiteEvent.where("#{where_case} AND site_id IN (#{site_ids.join(",")}) AND status = 1", search_param: "%#{params[:sSearch]}%") 
        end
      else
        related_site_ids = @object.related_site_ids
        if related_site_ids.present?
          events = status ? SiteEvent.where("#{where_case} AND site_id IN (#{related_site_ids.join(",")})", search_param: "%#{params[:sSearch]}%") 
                          : SiteEvent.where("#{where_case} AND site_id IN (#{related_site_ids.join(",")}) AND status = 1", search_param: "%#{params[:sSearch]}%") 
        end
      end
    else
      if @type
        site_ids = Site.where(trial: @object, status: 1).map(&:id)
        if site_ids.present?
          where_case = "site_id IN (#{site_ids.join(",")}) AND source != '#{SiteEvent::SOURCE[:forecasting]}'"
          events = status ? SiteEvent.where(where_case) : SiteEvent.where("#{where_case} AND status = 1")
        end
      else
        related_site_ids = @object.related_site_ids
        if related_site_ids.present?
          where_case = "site_id IN (#{related_site_ids.join(",")}) AND source != '#{SiteEvent::SOURCE[:forecasting]}'"
          events = status ? SiteEvent.where(where_case) : SiteEvent.where("#{where_case} AND status = 1")
        end
      end
    end
    
    events = events.order("#{sort_column} #{sort_direction}") if events.present?
    events.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[event_log_id happened_at event_id description source status]
    @type ? columns[params[:iSortCol_0].to_i-1] : columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
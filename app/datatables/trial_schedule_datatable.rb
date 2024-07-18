class TrialScheduleDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, trial)
    @view   = view
    @user   = user
    @trial  = trial
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: schedules.count,
      iTotalDisplayRecords: schedules.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    schedules.map do |schedule|
      schedule_id = schedule.id.to_s
      [
        link_to(schedule.name, "javascript: edit_schedule('/dashboard/trial/#{@trial.id.to_s}/schedules/#{schedule_id}/edit')"),
        '',
        "row_#{schedule_id}"
      ]
    end
  end

  def schedules
    @schedules ||= fetch_schedules
  end

  def fetch_schedules
    if params[:sSearch].present?
      where_case = "name LIKE :search_param AND trial_id = #{@trial.id}"
      schedules = TrialSchedule.where(where_case, search_param: "%#{params[:sSearch]}%")
    else
      schedules = @trial.trial_schedules
    end

    schedules.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[name sites]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
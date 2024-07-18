class TodoTasksDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user)
    @view = view
    @user = user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: tasks.count,
      iTotalDisplayRecords: tasks.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    tasks.map do |task|
      label2 = link_to(task[:site_id], "/dashboard/site/sites/#{task[:site].id}/dashboard", title: task[:site].name)
      [
        task[:trial_id],
        task[:country],
        label2,
        User::TASK_STATUS.key(task[:status]).to_s.gsub("_", " ")
      ]
    end
  end

  def tasks
    @tasks ||= fetch_tasks
  end

  def fetch_tasks
    filters = search_params
    user_tasks = @user.tasks.select {|task| is_task_matching_with_filters?(task, filters)}
    tasks = sort_array_with_data(user_tasks, sort_column, sort_direction)
    tasks.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[trial_id country site_id status]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

  def search_params
    opts = params[:sSearch].split(",")
    search_params = {}
    search_params[:trial_id] = opts[0].to_i if opts[0].present?
    search_params[:country]  = opts[1]      if opts[1].present?
    search_params[:site_id]  = opts[2].to_i if opts[2].present?
    search_params[:status]   = opts[3].to_i if opts[3].present?
    search_params
  end

  def is_task_matching_with_filters?(task, filters)
    filters.each do |key, value|
      key_string = key.to_s
      if key_string == "trial_id"
        return false if task[:trial].id != value
      elsif key_string == "site_id" 
        return false if task[:site].id != value
      elsif task[key] != value
        return false
      end
    end
    return true
  end
end
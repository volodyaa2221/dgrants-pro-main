class TrialPassthroughBudgetDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, trial, schedule)
    @view     = view
    @user     = user
    @trial    = trial
    @schedule = schedule
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: budgets.count,
      iTotalDisplayRecords: budgets.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    trial_id  = @trial.id.to_s
    symbol    = @schedule.vpd_currency.present? ? @schedule.vpd_currency.symbol : "$"
    budgets.map do |budget|
      status = budget.status > 0
      if status 
        name_label    = link_to(budget.name, "/dashboard/trial/#{trial_id}/passthrough_budgets/#{budget.id.to_s}/edit", remote: true)
        status_label  = link_to("<i class='fa fa-trash fa-lg'></i>".html_safe, "javascript: update_data('#{budget.id.to_s}', 'Passthrough Budget', 'passthrough budget')")
      else
        name_label    = budget.name
        status_label  = ''
      end
      max_amount = !budget.max_amount.zero? ? "%0.2f" % budget.max_amount : nil
      monthly_amount = !budget.monthly_amount.zero? ? "%0.2f" % budget.monthly_amount : nil
      [ 
        status ? name_label : "<del>#{name_label}</del>".html_safe,
        max_amount.nil? ? nil : symbol,
        status ? max_amount : "<del>#{max_amount}</del>".html_safe,
        monthly_amount.nil? ? nil : symbol,
        status ? monthly_amount : "<del>#{monthly_amount}</del>".html_safe,
        status_label,
        "row_#{budget.id.to_s}"
      ]
    end
  end

  def budgets
    @budgets ||= fetch_budgets
  end

  def fetch_budgets
    budgets = TrialPassthroughBudget.where(trial_schedule: @schedule).order(status: :desc, updated_at: :desc)

    budgets.paginate(page: page, per_page: per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 1000
  end

  def sort_column
    columns = %w[type_id currency amount tax_rate currency advance]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
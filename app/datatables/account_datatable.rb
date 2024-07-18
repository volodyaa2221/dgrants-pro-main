class AccountDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user)
    @view = view
    @user = user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: accounts.count,
      iTotalDisplayRecords: accounts.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    accounts.map do |account|
      vpd_trial_name = account.trial.nil? ? account.vpd_name : "#{account.vpd_name}/#{account.trial_name}"
      [
        account.ref_id,
        link_to(vpd_trial_name, "javascript: show_finance('/dashboard/show_finance?account=#{account.id.to_s}')").html_safe,
        @view.number_to_currency(account.pre_post, unit: '$'),
        @view.number_to_currency(account.remitted, unit: '$'),
        @view.number_to_currency(account.balance, unit: '$'),
        "row_#{account.id.to_s}"
      ]
    end
  end

  def accounts
    @accounts ||= fetch_accounts
  end

  def fetch_accounts
    if params[:sSearch].present?
      accounts = Account.where("ref_id LIKE :search_param OR vpd_name LIKE :search_param OR trial_name LIKE :search_param", search_param: "%#{params[:sSearch]}%")
    else
      accounts = Account.all
    end

    accounts.order("#{sort_column} #{sort_direction}").paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[ref_id vpd_name pre_post paid balance]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
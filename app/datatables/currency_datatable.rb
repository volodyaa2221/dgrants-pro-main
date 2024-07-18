class CurrencyDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, vpd=nil)
    @view = view
    @user = user
    @vpd  = vpd
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: currencies.count,
      iTotalDisplayRecords: currencies.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    currencies.map do |currency|
      url = @vpd.present? ? "/dashboard/vpd/#{@vpd.id.to_s}/currencies/#{currency[:id]}/update_status" : "/dashboard/update_status"
      [
        @vpd.present? ? currency[:code] : link_to(currency[:code], "/dashboard/currencies/#{currency[:id].to_s}/edit", remote: true),
        currency[:symbol],
        currency[:rate],
        currency[:description],
        currency[:sites]>0 ? currency[:sites] : '',
        "<div class='btn-group btn-toggle' data-update-url='#{url}'>
            <button class='btn btn-xs #{currency[:status]==1 ? 'btn-success active' : 'btn-default'}' style='padding:1px 5px' data-id='#{currency[:id].to_s}' data-status='1' data-type='#{currency[:class_name]}'>Yes</button>
            <button class='btn btn-xs #{currency[:status]==0 ? 'btn-warning active' : 'btn-default'}' style='padding:1px 5px' data-id='#{currency[:id].to_s}' data-status='0' data-type='#{currency[:class_name]}'>No</button>
          </div>".html_safe,
        "row_"+currency[:id].to_s
      ]
    end  
  end

  def currencies
    @currencies ||= fetch_currencies
  end

  def fetch_currencies   
    status = params[:show_option].strip == "Include disabled"  ?  false : true

    currencies = []
    if @vpd.present?
      currency_ids = @vpd.vpd_currencies.map(&:currency_id)
      if params[:sSearch].present?
        where_case = "code LIKE :search_param AND vpd_id = #{@vpd.id}"
        currencies = status ? VpdCurrency.where(where_case, search_param: "%#{params[:sSearch]}%") 
                          : VpdCurrency.where("#{where_case} AND status = 1", search_param: "%#{params[:sSearch]}%")
      else 
        currencies = status ? @vpd.vpd_currencies : VpdCurrency.where(vpd: @vpd, status: 1)
      end
      currencies   = currencies.map do |currency|
        {id: currency.id.to_s, code: currency.code, description: currency.description, symbol: currency.symbol, rate: currency.rate,
          sites: SiteSchedule.where(vpd_currency: currency, status: 1).count, status: currency.status, class_name: currency.class.name}
      end
      if status
        temp = []
        where_case = currency_ids.present? ? "id NOT IN (#{currency_ids.join(",")}) AND status = 1" : "status = 1"
        temp = params[:sSearch].present? ? Currency.where("#{where_case} AND code LIKE :search_param", search_param: "%#{params[:sSearch]}%") 
                                         : Currency.where(where_case)
        temp   = temp.map do |currency|
          {id: currency.id.to_s, code: currency.code, description: currency.description, symbol: currency.symbol, rate: currency.rate,
            sites: 0, status: 0, class_name: currency.class.name}
        end
        currencies = currencies.concat(temp)
      end
    else
      if params[:sSearch].present?
        currencies = status ? Currency.where("code LIKE :search_param", search_param: "%#{params[:sSearch]}%") 
                            : Currency.where("code LIKE :search_param AND status = 1", search_param: "%#{params[:sSearch]}%")
      else
        currencies = status ? Currency.all : Currency.activated_currencies
      end
      currencies = currencies.map do |currency|
        {id: currency.id.to_s, code: currency.code, description: currency.description, symbol: currency.symbol, rate: currency.rate,
          sites: SiteSchedule.where(currency: currency, status: 1).count, status: currency.status, class_name: currency.class.name}
      end
    end 

    currencies = sort_array_with_data(currencies, sort_column, sort_direction)
    currencies.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 15
  end

  def sort_column
    columns = %w[code symbole rate description sites]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
class PostDatatable
  include DatatableHelper

  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view, user, account)
    @view     = view
    @user     = user
    @account  = account
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: posts.count,
      iTotalDisplayRecords: posts.total_entries,
      aaData: data.compact
    }
  end

private
  def data
    invoice_status = Invoice::STATUS.map do |k, v|
      k.to_s.humanize.upcase
    end

    if @account.trial.present?
      vpd = @account.vpd
      tier1_amount = vpd.tier1_amount.present? && vpd.tier1_amount>0  ?  vpd.tier1_amount : 0

      approver_types = VpdApprover.where(user: @user, vpd: @account.vpd, status: 1).map{|approver| approver.type}
    end

    posts.map do |post|
      status = post[:type] == Post::TYPE[:credit]  ?  '' : '-'
      if post[:type] == Post::TYPE[:payment]  &&  post[:status] < Invoice::STATUS[:paid_offline]
        unless approver_types.blank?
          if tier1_amount >= post[:amount]
            if approver_types.include?(0)
              status_label = link_to(invoice_status[post[:status]], "/dashboard/site/0/invoices/#{post[:id]}/edit?approver_type=#{approver_types.max}", remote: true)
            else
              status_label = invoice_status[post[:status]]
            end                
          else
            if approver_types.include?(1)
              status_label = link_to(invoice_status[post[:status]], "/dashboard/site/0/invoices/#{post[:id]}/edit?approver_type=1", remote: true)
            else
              status_label = invoice_status[post[:status]]
            end
          end
        else
          status_label = invoice_status[post[:status]]
        end
      else
        status_label = invoice_status[post[:status]]
      end
      [
        post[:created_at].strftime('%e %b %Y'),
        post[:description],
        "#{status} $ #{@view.number_to_currency(post[:amount].round(2), unit: '')} #{post[:status]<3 ? '*' : ''}",
        status_label,
        "row_#{post[:id]}"
      ]
    end
  end

  def posts
    @posts ||= fetch_posts
  end

  def fetch_posts
    posts = Post.where(account: @account).map do |post|
      if post.type == Post::TYPE[:credit]
        description = "Deposit"
      elsif post.type == Post::TYPE[:debit]
        description = "Debit"
      elsif post.type == Post::TYPE[:fee]
        description = "All inclusive bank & system charges"
      elsif post.type == Post::TYPE[:payment]
        invoice = post.invoice
        invoice_label = link_to("##{invoice.invoice_no}", "/dashboard/site/#{invoice.site.id.to_s}/invoices/#{invoice.id.to_s}").html_safe
        description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency_code} #{@view.number_to_currency(invoice.amount, unit: '')})"
      end
      {id: post.id.to_s, created_at: post.created_at, description: description, amount: post.amount, status: 7, type: post.type}
    end

    Invoice.where("account_id = #{@account.id} AND status < #{Invoice::STATUS[:deleted]}").each do |invoice|
      invoice_label = link_to("##{invoice.invoice_no}", "/dashboard/site/#{invoice.site.id.to_s}/invoices/#{invoice.id.to_s}").html_safe
      status = invoice.status
      if status < Invoice::STATUS[:pending_queued]
        description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency.code} #{@view.number_to_currency(invoice.amount, unit: '')}) PENDING #{invoice.pay_at.strftime('%e %b %Y')}"
      elsif status == Invoice::STATUS[:pending_queued]  ||  status == Invoice::STATUS[:rejected]
        if invoice.sent_at.present?
          description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency.code} #{@view.number_to_currency(invoice.amount, unit: '')}) FUNDS SETNT #{invoice.sent_at.strftime('%e %b %Y')}"
        else
          description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency.code} #{@view.number_to_currency(invoice.amount, unit: '')}) PENDING #{invoice.pay_at.strftime('%e %b %Y')}"
        end
      elsif status == Invoice::STATUS[:successful]
        description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency.code} #{@view.number_to_currency(invoice.amount, unit: '')}) PAYMENT MADE #{invoice.pay_at.strftime('%e %b %Y')}"
      else # paid_offline
        description = "Payment of Site Invoice #{invoice_label} (#{invoice.currency.code} #{@view.number_to_currency(invoice.amount, unit: '')})"
      end
      usd_amount    = invoice.amount * invoice.usd_rate
      posts << {id: invoice.id.to_s, created_at: invoice.created_at, description: description, amount: usd_amount, status: status, type: Post::TYPE[:payment]}
    end

    posts = posts.select{|post| post[:description] =~ /^.*#{params[:sSearch]}.*$/i} if params[:sSearch].present?

    posts = sort_array_with_data(posts, sort_column, sort_direction)
    posts.paginate(page: page, :per_page => per_page)
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10000
  end

  def sort_column
    columns = %w[created_at description amount]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
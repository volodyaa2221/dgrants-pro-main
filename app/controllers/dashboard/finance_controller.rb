class Dashboard::FinanceController < DashboardController
  before_action :authenticate_verify_user
  before_action :authenticate_super_admin

  # Finance actions
  #----------------------------------------------------------------------
  # GET   /dashboard/finance(.:format) 
  def index
    @total_balance = Account.sum(:balance)
    @post = Post.new
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: AccountDatatable.new(view_context, current_user) }
    end
  end

  # POST|PUT|PATCH  /dashboard/save_finance(.:format) 
  def save_finance
    account = Account.where(ref_id: params[:post][:ref_id])
    if account.exists?
      params[:post][:amount] = params[:post][:amount].to_f
      if params[:post][:amount] > 0
        account = account.first
        params[:post][:vpd_id] = account.vpd.id
        post = account.posts.build(post_params)
        if post.save
          total_balance = Account.sum(:balance)
          total_money = view_context.number_to_currency(total_balance, unit: '$')
          if account.trial.present?
            trial = account.trial
            data = {success:{msg: "Posting Added", name: "#{trial.vpd.name}/#{trial.trial_id}", total_money: total_money}}
          else
            data = {success:{msg: "Posting Added", name: "DRUGDEV", total_money: total_money}}
          end
        else
          data = {failure:{msg: post.errors.full_messages.first}}
        end
      else
        data = {failure:{msg: "Invalid Amount"}}
      end
    else
      data = {failure:{msg: "Invalid REFID"}}
    end

    render json: data
  end

  # GET  /dashboard/show_finance(.:format) 
  def show_finance
    @account = Account.find(params[:account])
    after_posting = @account.usd_amount_after_posting
    @after_posting_label = after_posting >= 0  ?  "Balance after postings: $ #{view_context.number_to_currency(after_posting, unit: '')}" :
                                                "Balance after postings: - $ #{view_context.number_to_currency(after_posting.abs, unit: '')}"
    respond_to do |format|
      format.html { render layout: params[:type] != "ajax" }
      format.json { render json: PostDatatable.new(view_context, current_user, @account) }
    end
  end


  # Private methods
  #----------------------------------------------------------------------
  private
  def post_params
    params.require(:post).permit(:type, :amount).tap do |whitelisted|
      whitelisted[:vpd_id] = params[:post][:vpd_id]
    end
  end
end
class Dashboard::Trial::AccountsController < DashboardController
  include Dashboard::TrialHelper

  before_action :get_trial
  before_action :authenticate_verify_user
  before_action :authenticate_trial_editable_user, except: :index
  before_action :authenticate_trial_level_user, only: :index

  # Trial Event actions
  #----------------------------------------------------------------------
  # GET   /dashboard/trial/:trial_id/balance(.:format) 
  def balance
    @account = @trial.account
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
end
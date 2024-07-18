module Dashboard::TrialHelper

  def get_trial
    @trial = params[:trial_id].present? ? Trial.find(params[:trial_id].to_i) : Trial.find(params[:id].to_i)
  end

  # Private: Check if the user is trial level user
  def authenticate_trial_level_user
    if current_user.trial_level_user?(@trial)
      true
    else
      flash[:error] = "Access is for Trial admin only"
      redirect_to request.referrer
    end
  end

  # Private: Check if the user can edit trial data
  def authenticate_trial_editable_user
    if current_user.trial_editable?(@trial)
      true
    else
      flash[:error] = "Access is for Trial admin only"
      redirect_to request.referrer
    end
  end
end
module Dashboard::VpdHelper

  def get_vpd
    @vpd = params[:vpd_id].present? ? Vpd.find(params[:vpd_id].to_i) : Vpd.find(params[:id].to_i)
  end

  # Public: Check if the user is vpd level user
  def authenticate_vpd_level_user
    if current_user.vpd_level_user?
      return true
    else
      flash[:error] = "Access is for VPD admin only"
      redirect_to request.referrer || dashboard_path
    end
  end
end
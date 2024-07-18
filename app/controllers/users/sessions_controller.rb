class Users::SessionsController < Devise::SessionsController
  # GET /users/sign_in
  def new
    redirect_to root_url
  end

  # POST /users/sign_in
  def create
    user = User.where(email: params[:user][:email].strip).first
    data = nil
    if user.present?
      if user.status == 0
        flash[:error] = "Your account was disabled"
        data = { failure: "Your account was disabled" }
        render json: data, status: :not_found and return
      else
        resource = warden.authenticate!(scope: resource_name, recall: "#{controller_path}#failure")
        sign_in_and_redirect(resource_name, resource)
        flash.delete(:error)
      end
    else
      render json: {failure: "Can't find account"}, status: :not_found and return
    end
  end

  def sign_in_and_redirect(resource_or_scope, resource=nil)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    resource ||= resource_or_scope
    sign_in(scope, resource) unless warden.user(scope) == resource
    return render json: { success: true }
  end

  def failure
    return render json: { success: false, error: ["Login failed."] }
  end

  def destroy
    sign_out(:user)
    sign_out_and_redirect(resource_name)
  end
end
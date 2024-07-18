class Dashboard::Vpd::MailTemplatesController < DashboardController
  include Dashboard::VpdHelper

  before_action :get_vpd
  before_action :authenticate_verify_user
  before_action :authenticate_vpd_level_user

  # VPD MailTemplate actions
  #----------------------------------------------------------------------
  # GET   /dashboard/vpd/:vpd_id/mail_templates(.:format)
  def index
    respond_to do |format|
      format.html{ render layout: !params[:type] == "ajax" }
      format.json{ render json: VpdMailtemplateDatatable.new(view_context, @vpd) }
    end
  end

  # GET   /dashboard/vpd/:vpd_id/mail_templates/:id/edit(.:format)
  def edit
    @mail_temp = VpdMailTemplate.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  # PUT|PATCH   /dashboard/vpd/:vpd_id/mail_templates/:id(.:format)
  def update
    mail_temp = VpdMailTemplate.find(params[:id]) 
    if mail_temp.update_attributes(mail_template_params)
      data = {success:{msg: "Mail Template Updated", type: mail_temp.type_label}}
    else
      key, val = mail_temp.errors.messages.first
      data = {failure:{msg: mail_temp.errors.full_messages.first, element_id: "vpd_mail_template_#{key}"}}
    end
    render json: data
  end


  # Private methods
  #----------------------------------------------------------------------
  private

  def mail_template_params
    params.require(:vpd_mail_template).permit(:type, :subject, :body)    
  end
end
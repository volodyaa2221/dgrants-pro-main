class VpdMailTemplate < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Constants
  #----------------------------------------------------------------------
  # Can't change this mail templates because this template doesn't have VPD
  # expired_email:                  0,
  # confirmation_email:             1,
  # contact_email:                  2,
  MAIL_TYPE = {  
                  invited_vpd_admin:        3,
                  invited_trial_admin:      4,
                  invited_trial_associate:  5,
                  invited_site_admin:       6,
                  invited_site_user:        7,
                  added_to_new_trial:       8,
                  added_to_new_site:        9
                }

  MAIL_SUBJECT = {
    invited_vpd_admin:        "Invitation for VPD Admin",
    invited_trial_admin:      "Invitation for Trial Admin",
    invited_trial_associate:  "Invitation for Site Monitor",
    invited_site_admin:       "Invitation for Site Admin",
    invited_site_user:        "Invitation for Site User",
    added_to_new_trial:       "Invitation for Trial Admin",
    added_to_new_site:        "Invitation for Site User"
  }

  MAIL_BODY = {
    invited_vpd_admin:        "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a VPD administrator for the *VPD_NAME*.VPD system.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.\r\n"\
                              "To start managing your virtual private database, please click the link below to set up your #{Dgrants::Application::CONSTS[:app_name]} account:",
    invited_trial_admin:      "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a Trial Administrator for the study *TRIAL_ID*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.\r\n"\
                              "To start managing your virtual private database, please click the link below to set up your #{Dgrants::Application::CONSTS[:app_name]} account:",
    invited_trial_associate:  "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a Site Monitor for site *SITE_ID*:*SITE_NAME*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.\r\n"\
                              "To start managing your virtual private database, please click the link below to set up your #{Dgrants::Application::CONSTS[:app_name]} account:",
    invited_site_admin:       "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a Site Administrator for site *SITE_ID*:*SITE_NAME*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.\r\n"\
                              "To start managing your virtual private database, please click the link below to set up your #{Dgrants::Application::CONSTS[:app_name]} account:",
    invited_site_user:        "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a Site User for site *SITE_ID*:*SITE_NAME*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.\r\n"\
                              "To start managing your virtual private database, please click the link below to set up your #{Dgrants::Application::CONSTS[:app_name]} account:",
    added_to_new_trial:       "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a *ROLE* for the study *TRIAL_ID*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials.",
    added_to_new_site:        "*MANAGER_NAME* (*MANAGER_EMAIL*) has set you up in #{Dgrants::Application::CONSTS[:app_name]} as a *ROLE* for site *SITE_ID*:*SITE_NAME*.\r\n"\
                              "#{Dgrants::Application::CONSTS[:app_name]} is a cloud based prescreen tool that can accelerate feasibility and improve site selection for multi center clinical trials."
  }

  # Associations
  #----------------------------------------------------------------------c
  belongs_to :vpd

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of   :type
  validates_uniqueness_of :type, scope: :vpd_id

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_mail_templates, -> {where(status: 1)}

  # Class methods
  #----------------------------------------------------------------------
  def self.mail_content(content, object=nil, role_label=nil, manager=nil, type)
    content = content.gsub("*MANAGER_NAME*", manager.name).gsub("*MANAGER_EMAIL*", "<a href='mailto:#{manager.email}'>#{manager.email}</a>")
    return content if object.nil?
    if type == MAIL_TYPE[:invited_vpd_admin]
      content.gsub("*VPD_NAME*", object.name)
    elsif type == MAIL_TYPE[:invited_trial_admin]
      content.gsub("*VPD_NAME*", object.vpd.name).gsub("*TRIAL_ID*", object.trial_id)
    elsif type >= MAIL_TYPE[:invited_trial_associate] && type <= MAIL_TYPE[:invited_site_user]
      content.gsub("*VPD_NAME*", object.vpd.name).gsub("*TRIAL_ID*", object.trial.trial_id).gsub("*SITE_ID*", object.site_id).gsub("*SITE_NAME*", object.name)
    elsif type == MAIL_TYPE[:added_to_new_trial]
      content.gsub("*VPD_NAME*", object.vpd.name).gsub("*TRIAL_ID*", object.trial_id).gsub("*ROLE*", role_label)
    elsif type == MAIL_TYPE[:added_to_new_site]
      content.gsub("*VPD_NAME*", object.vpd.name).gsub("*TRIAL_ID*", object.trial.trial_id).gsub("*SITE_ID*", object.site_id).gsub("*SITE_NAME*", object.name).gsub("*ROLE*", role_label)
    end
  end

  # Attribute methods
  #----------------------------------------------------------------------
  def mail_subject(object=nil, role_label=nil, manager=nil)
    VpdMailTemplate.mail_content(self.subject, object, role_label, manager, self.type)
  end

  def mail_body(object=nil, role_label=nil, manager=nil)
    VpdMailTemplate.mail_content(self.body, object, role_label, manager, self.type)
  end

  def type_label
    MAIL_TYPE.key(self.type).to_s.titleize
  end
end
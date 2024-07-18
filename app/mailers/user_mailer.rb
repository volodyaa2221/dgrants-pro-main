class UserMailer < Devise::Mailer
  include Devise::Mailers::Helpers  

  default from: Dgrants::Application::CONSTS[:contact_email]

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.expire_email.subject
  #
  # def expire_email(user)
  #   mail(:to => user.email, subject: "Subscription Cancelled")
  # end
  
  # def confirmation_email(user)
  #   mail(:to => user.email, subject: "Created new account")
  # end

  # Mailer actions
  #----------------------------------------------------------------------
  def contact_email(name, email, text)
    @name = name
    @email = email
    @text = text
    mail(to: :from, subject: "Contact")
  end

  # Send email when invited in a super admin
  def invited_super_admin(user)
    @user     = user
    mail(to: @user.email, subject: "Invitation for Super Admin")
  end

  # Send email when invited in a vpd
  def invited_vpd_admin(user, vpd)
    @user     = user
    template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_vpd_admin])
    subject_and_body(template, vpd, role_label=nil, user.manager, VpdMailTemplate::MAIL_TYPE[:invited_vpd_admin])
    mail(to: @user.email, subject: @subject)
  end

  # Send email when added to new trial
  def added_to_new_trial(user, trial, role_label)
    @user     = user
    vpd       = trial.vpd
    template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:added_to_new_trial])
    subject_and_body(template, trial, role_label, user.manager, VpdMailTemplate::MAIL_TYPE[:added_to_new_trial])
    mail(to: @user.email, subject: @subject)
  end

  # Send email when added to new site
  def added_to_new_site(user, site, role_label)
    @user     = user
    vpd       = site.vpd
    template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:added_to_new_site])
    subject_and_body(template, site, role_label, user.manager, VpdMailTemplate::MAIL_TYPE[:added_to_new_site])
    mail(to: @user.email, subject: @subject)
  end

  def reminder_prescreen(user, site)
    @user     = user
    template  = site.vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:reminder_prescreen])
    if template.present?
      @subject = template.subject
      @body    = template.body.gsub("\r\n", "<br/>")
    else
      @subject = "Please check #{site.site_id}"
    end
    mail(to: @user.email, subject: @subject)
  end

  def confirmation_instructions(record, token, opts={})
    headers["template_path"] = "user_mailer"
    headers["template_name"] = "confirmation_instructions"
    headers({'X-No-Spam' => 'True', 'In-Reply-To' => Dgrants::Application::CONSTS[:contact_email]})
    headers['X-MC-Track'] = "False, False"

    if record.role_type == Role::ROLE[:vpd_admin]
      vpd       = record.invited_to_object
      template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_vpd_admin])
      subject_and_body(template, vpd, role_label=nil, record.manager, VpdMailTemplate::MAIL_TYPE[:invited_vpd_admin])
    elsif record.role_type == Role::ROLE[:trial_admin]  ||  record.role_type == Role::ROLE[:trial_readonly]
      trial     = record.invited_to_object
      vpd       = trial.vpd
      template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_trial_admin])
      subject_and_body(template, trial, role_label=nil, record.manager, VpdMailTemplate::MAIL_TYPE[:invited_trial_admin])
    elsif record.role_type == Role::ROLE[:trial_associate]
      site      = record.invited_to_object
      vpd       = site.vpd
      template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_trial_associate])
      subject_and_body(template, site, role_label=nil, record.manager, VpdMailTemplate::MAIL_TYPE[:invited_trial_associate])
    elsif record.role_type == Role::ROLE[:site_admin] || record.role_type == Role::ROLE[:site_readonly]
      site      = record.invited_to_object
      vpd       = site.vpd
      template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_site_admin])
      subject_and_body(template, site, role_label=nil, record.manager, VpdMailTemplate::MAIL_TYPE[:invited_site_admin])
    elsif record.role_type == Role::ROLE[:site_user]
      site      = record.invited_to_object
      vpd       = site.vpd
      template  = vpd.mailtemplate(VpdMailTemplate::MAIL_TYPE[:invited_site_user])
      subject_and_body(template, site, role_label=nil, record.manager, VpdMailTemplate::MAIL_TYPE[:invited_site_user])
    end
    opts = {subject: @subject}
    super
  end

  def reset_password_instructions(record, token, opts={})
    headers["template_path"] = "user_mailer"
    headers["template_name"] = "reset_password_instructions"
    headers({'X-No-Spam' => 'True', 'In-Reply-To' => Dgrants::Application::CONSTS[:contact_email]})
    headers['X-MC-Track'] = "False, False"
    super
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  # Private: Builds subject and body by template
  def subject_and_body(template, object, role_label, manager, type)
    if template.present?
      @subject = template.mail_subject(object, role_label, manager)
      @body    = template.mail_body(object, role_label, manager).gsub("\r\n", "<br/>")
    else
      key      = VpdMailTemplate::MAIL_TYPE.invert[type]
      @subject = VpdMailTemplate::MAIL_SUBJECT[type]
      @body    = VpdMailTemplate.mail_content(VpdMailTemplate::MAIL_BODY[key], object, role_label, manager, type).gsub("\r\n", "<br/>")
    end
  end
end
module Dashboard::SiteHelper

  # Get site from params
  def get_site
    @site = params[:site_id].present? ? Site.find(params[:site_id].to_i) : Site.find(params[:id].to_i)
  end

  # Check if the user is site level user
  def authenticate_site_level_user
    if current_user.site_level_user?(@site)
      true
    else
      flash[:error] = "Access is for Site user only"
      redirect_to request.referrer
    end
  end

  # Check if the user can edit site data
  def authenticate_site_editable_user
    if current_user.site_editable?(@site)
      true
    else
      flash[:error] = "Access is for Site user only"
      redirect_to request.referrer
    end
  end

  # Check if the user can create site
  def authenticate_site_creatable_user
    current_user.trial_editable?(@trial)
  end

  # Check if the user can edit site details
  def authenticate_site_details_editable_user
    current_user.trial_editable?(@site.trial) || @site.trial_associate?(current_user)
  end

  # Get payee info to be shown in current invoice
  def current_invoice_payee_info
    first_section = ""
    if @site.payment_info.present? && @site.payment_info.field1_value.present?
      first_section += "<p>#{@site.payment_info.field1_value}</p>"
    end
    first_section    += "<p>#{@site.address}<p>" if @site.address.present?
    city_state       =  [@site.city, @site.state].compact.join(", ")
    first_section    += "<p>#{city_state}</p>" if city_state.present?
    country_postcode =  [@site.country_name, @site.zip_code].compact.join(", ")
    first_section    += "<p>#{country_postcode}</p>" if country_postcode.present?

    second_section = bank_name = bank_address = ""
    if @site.payment_info.present?
      (2..6).each do |i|
        key_sym = "field#{i}_label".to_sym
        val_sym = "field#{i}_value".to_sym
        if @site.payment_info[key_sym].present?
          label = @site.payment_info[key_sym]
          label = "Swift Code" if label.start_with?("SWIFT Code (")

          second_section += "<tr><td class='w30'><p>#{label}:</p></td>"\
                            "<td><p>#{@site.payment_info[val_sym]}</p></td></tr>"
        end
      end

      bank_name = "<p>#{@site.payment_info.bank_name}</p>"

      bank_street_address = [@site.payment_info.bank_street_address].join(": ")
      bank_city_state = [@site.payment_info.bank_city, @site.payment_info.bank_state].compact.join(", ")
      bank_country_postcode = [@site.payment_info.country, @site.payment_info.bank_postcode].compact.join(", ")
      bank_address += "<p>#{bank_street_address}</p>" if @site.payment_info.bank_street_address.present?
      bank_address += "<p>#{bank_city_state}</p>"     if bank_city_state.present?
      bank_address += "<p>#{bank_country_postcode}"   if bank_country_postcode.present?
    end

    return first_section, second_section, bank_name, bank_address
  end


  # Get payee info to be shown in current invoice
  def past_invoice_payee_info(invoice)
    first_section = second_section = bank_name = bank_address = ""
    payment_info = invoice.invoice_payment_info
    if payment_info.present?
      if payment_info.field1_value.present?
        first_section += "<p>#{payment_info.field1_value}</p>"
      end
      first_section    += "<p>#{@site.address}<p>" if @site.address.present?
      city_state       =  [payment_info.site_city, payment_info.site_state].compact.join(", ")
      first_section    += "<p>#{city_state}</p>" if city_state.present?
      country_postcode =  [payment_info.site_country, payment_info.site_postcode].compact.join(", ")
      first_section    += "<p>#{country_postcode}</p>" if country_postcode.present?

      second_section = bank_name = bank_address = ""
      (2..6).each do |i|
        key_sym = "field#{i}_label".to_sym
        val_sym = "field#{i}_value".to_sym
        if payment_info[key_sym].present?
          label = payment_info[key_sym]
          label = "Swift Code" if label.start_with?("SWIFT Code (")
          second_section += "<tr><td class='w30'><p>#{payment_info[key_sym]}:</p></td>"\
                            "<td><p>#{payment_info[val_sym]}</p></td></tr>"
        end
      end

      bank_name = "<p>#{payment_info.bank_name}</p>"

      bank_street_address = [payment_info.bank_street_address].join(": ")
      bank_city_state = [payment_info.bank_city, payment_info.bank_state].compact.join(", ")
      bank_country_postcode = [payment_info.bank_country, payment_info.bank_postcode].compact.join(", ")
      bank_address += "<p>#{bank_street_address}</p>" if payment_info.bank_street_address.present?
      bank_address += "<p>#{bank_city_state}</p>"     if bank_city_state.present?
      bank_address += "<p>#{bank_country_postcode}"   if bank_country_postcode.present?
    end
    return first_section, second_section, bank_name, bank_address
  end
end
class PaymentInfo < ActiveRecord::Base
  
  # Constants
  #----------------------------------------------------------------------

  # Associations
  #----------------------------------------------------------------------
  belongs_to :site

  # Validations
  #----------------------------------------------------------------------

  # Scopes
  #----------------------------------------------------------------------

  # Callbacks
  #----------------------------------------------------------------------

  # Flag methods
  #----------------------------------------------------------------------
  def missing_some_fields?
    missing_some_fields = country.blank? || currency_code.blank? || bank_name.blank? || bank_street_address.blank?
    missing_some_fields ||= bank_city.blank? || bank_state.blank? || bank_postcode.blank?
    missing_some_fields ||= (field1_label.present? && field1_value.blank?)
    missing_some_fields ||= (field2_label.present? && field2_value.blank?)
    missing_some_fields ||= (field3_label.present? && field3_value.blank?)
    missing_some_fields ||= (field4_label.present? && field4_value.blank?)
    missing_some_fields ||= (field5_label.present? && field5_value.blank?)
    missing_some_fields ||= (field6_label.present? && field6_value.blank?)
  end

  # Private methods
  #----------------------------------------------------------------------
  private
  
end

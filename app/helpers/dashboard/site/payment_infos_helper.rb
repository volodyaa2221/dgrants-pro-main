module Dashboard::Site::PaymentInfosHelper

  # Returns Roo Spreadsheet from a file
  def country_payment_info(country_name)
    info = {}
    spreadsheet = Roo::Excelx.new("#{Rails.root}/db/res/PIF.xlsx", file_warning: :ignore)
    spreadsheet.parse(:clean => true)
    (2..spreadsheet.last_row).each do |spreadsheet_row_index|
      data_row = spreadsheet.row(spreadsheet_row_index)
      if data_row[0].to_s == country_name
        info[:currency_codes] = data_row[1].present? ? data_row[1].to_s.split(",") : []
        info[:field1_label] = data_row[2].present? ? data_row[2].to_s.strip : ""
        info[:field2_label] = data_row[4].present? ? data_row[4].to_s.strip : ""
        info[:field3_label] = data_row[6].present? ? data_row[6].to_s.strip : ""
        info[:field4_label] = data_row[8].present? ? data_row[8].to_s.strip : ""
        info[:field5_label] = data_row[10].present? ? data_row[10].to_s.strip : ""
        info[:field6_label] = data_row[12].present? ? data_row[12].to_s.strip : ""
      end 
    end
    info
  end
end
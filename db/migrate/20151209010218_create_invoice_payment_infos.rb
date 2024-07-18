class CreateInvoicePaymentInfos < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_payment_infos do |t|
      # Payment information (site info, payment info)
      # at the moment an invoice was submitted
      t.string      :payee_name
      t.string      :site_address
      t.string      :site_city
      t.string      :site_state
      t.string      :site_country
      t.string      :site_postcode
      t.string      :field2_label
      t.string      :field2_value
      t.string      :field3_label
      t.string      :field3_value
      t.string      :field4_label
      t.string      :field4_value
      t.string      :field5_label
      t.string      :field5_value
      t.string      :field6_label
      t.string      :field6_value
      t.string      :bank_street_address
      t.string      :bank_city
      t.string      :bank_state
      t.string      :bank_country
      t.string      :bank_postcode
      t.references  :invoice,                  index: true

      t.timestamps  null: false
    end
  end
end

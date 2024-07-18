class CreatePaymentInfos < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_infos do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string :country               # Country Name
      t.string :payable               # Currency Code for Country
      t.string :field1_label          # Custom Field 1 Label
      t.string :field1_value          # Custom Field 1 Value
      t.string :field2_label          # Custom Field 2 Label
      t.string :field2_value          # Custom Field 2 Value
      t.string :field3_label          # Custom Field 3 Label
      t.string :field3_value          # Custom Field 3 Value
      t.string :field4_label          # Custom Field 4 Label
      t.string :field4_value          # Custom Field 4 Value
      t.string :field5_label          # Custom Field 5 Label
      t.string :field5_value          # Custom Field 5 Value
      t.string :field6_label          # Custom Field 6 Label
      t.string :field6_value          # Custom Field 6 Value
      t.string :bank_name             # Bank Name
      t.string :bank_street_address   # Bank Stree Address
      t.string :bank_city             # Bank City
      t.string :bank_state            # Bank State
      t.string :bank_postcode         # Bank Postcode

      t.timestamps null: false
    end

    add_reference :payment_infos,  :site, index: true
  end
end

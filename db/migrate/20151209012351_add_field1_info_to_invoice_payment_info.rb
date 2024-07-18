class AddField1InfoToInvoicePaymentInfo < ActiveRecord::Migration[7.1]
  def change
    remove_column :invoice_payment_infos, :payee_name
    
    add_column    :invoice_payment_infos, :field1_label, :string
    add_column    :invoice_payment_infos, :field1_value, :string
  end
end

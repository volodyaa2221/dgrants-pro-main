class AddBankNameToInvoicePaymentInfo < ActiveRecord::Migration[7.1]
  def change
    add_column :invoice_payment_infos, :bank_name, :string
  end
end

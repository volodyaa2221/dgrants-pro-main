class AddCurrencyCodeToInvoicePaymentInfo < ActiveRecord::Migration[7.1]
  def change
    add_column :invoice_payment_infos, :currency_code, :string
  end
end

class AddCurrencyFieldToPaymentInfos < ActiveRecord::Migration[7.1]
  def change
    add_column    :payment_infos, :currency_code, :string
    remove_column :payment_infos, :payable
  end
end

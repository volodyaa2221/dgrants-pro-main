class CreateInvoiceFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_files do |t|

      t.timestamps null: false
    end
  end
end

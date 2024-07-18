class AddInvoiceReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoice_files, :invoice, index: true
    add_reference :posts,         :invoice, index: true
    add_reference :transactions,  :invoice, index: true
  end
end

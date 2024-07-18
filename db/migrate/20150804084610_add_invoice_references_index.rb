class AddInvoiceReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :invoice_files, [:id, :invoice_id]
    add_index :posts,         [:id, :invoice_id]
    add_index :transactions,  [:id, :invoice_id]
  end
end

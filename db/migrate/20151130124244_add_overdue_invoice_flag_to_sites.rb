class AddOverdueInvoiceFlagToSites < ActiveRecord::Migration[7.1]
  def change
    add_column :sites, :is_invoice_overdue, :integer, default: 0 # For current invoice overdue status (1: overdue otherwise 0)
  end
end

class AddTransferReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :invoices, [:id, :transfer_id]
  end
end

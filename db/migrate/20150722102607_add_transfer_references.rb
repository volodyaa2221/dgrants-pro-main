class AddTransferReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoices, :transfer, index: true
  end
end

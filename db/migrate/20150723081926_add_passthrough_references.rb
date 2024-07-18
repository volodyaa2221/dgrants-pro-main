class AddPassthroughReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoice_files, :passthrough, index: true
    add_reference :transactions,  :passthrough, index: true
  end
end

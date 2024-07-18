class AddPassthroughReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :invoice_files, [:id, :passthrough_id]
    add_index :transactions,  [:id, :passthrough_id]
  end
end

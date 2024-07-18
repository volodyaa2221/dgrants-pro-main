class AddSiteEntryReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :transactions, [:id, :site_entry_id]
  end
end

class AddVpdLedgerCategoryReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :trial_entries, [:id, :vpd_ledger_category_id]
    add_index :site_entries,  [:id, :vpd_ledger_category_id]
  end
end

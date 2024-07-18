class AddVpdLedgerCategoryReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :trial_entries, :vpd_ledger_category, index: true
    add_reference :site_entries,  :vpd_ledger_category, index: true
  end
end

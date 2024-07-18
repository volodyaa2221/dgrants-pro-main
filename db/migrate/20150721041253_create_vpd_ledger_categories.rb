class CreateVpdLedgerCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_ledger_categories do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string :name,     default: ""   # VPD Ledger Category Name
      t.integer :status,  default: 1    # Active/Disable
      t.integer :sync,    default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

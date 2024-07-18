class CreateVpdCurrencies < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_currencies do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :code                       # Currency Code
      t.string  :description                # Currency Description
      t.string  :symbol,      default: ""   # Currency Symbol
      t.float   :rate                       # Currency Exchange Rate VS USD
      t.integer :status,      default: 1    # Active/Disable
      t.integer :sync,        default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

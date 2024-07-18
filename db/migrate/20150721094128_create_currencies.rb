class CreateCurrencies < ActiveRecord::Migration[7.1]
  def change
    create_table :currencies do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :code                     # Currency Code
      t.string  :description              # Currency Description
      t.string  :symbol                   # Currency Symbol
      t.float   :rate,        default: 1  # Currency Exchange Rate against USD
      t.integer :status,      default: 1  # Active/Disable

      t.timestamps null: false
    end
  end
end

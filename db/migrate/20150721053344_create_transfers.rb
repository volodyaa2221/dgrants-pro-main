class CreateTransfers < ActiveRecord::Migration[7.1]
  def change
    create_table :transfers do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :transfer_id, default: ""   # Unique Transfer ID
      t.string  :description, default: ""   # Transfer Description
      t.float   :amount,      default: 0.0  # Amount of Transfer
      t.integer :type,        default: 0.0  # 0: Site Invoice Payment, 1: Bank Charge, 2: Deposit 
      t.integer :status,      default: 0    # Active/Disable

      t.timestamps null: false
    end
  end
end

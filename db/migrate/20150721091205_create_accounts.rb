class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :ref_id,      default: ""   # Reference Id
      t.float   :balance,     default: 0    # Account Balance
      t.float   :pre_post,    default: 0    # Pre Post Amount
      t.float   :remitted,    default: 0    # Paid Amount
      t.string  :vpd_name,    default: ""   # Vpd Name
      t.string  :trial_name,  default: ""   # Trial ID
      t.integer :sync,        default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

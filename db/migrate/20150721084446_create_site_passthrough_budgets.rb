class CreateSitePassthroughBudgets < ActiveRecord::Migration[7.1]
  def change
    create_table :site_passthrough_budgets do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :name,            default: nil  # Passthrough Budget Name
      t.float   :max_amount,      default: 0    # Passthrough Budget Max Total Amount
      t.float   :monthly_amount,  default: 0    # Passthrough Budget Max Monthly Amount
      t.integer :status,          default: 2    # (0: Disabled, 1: Payable, 2: Editable)
      t.integer :sync,            default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

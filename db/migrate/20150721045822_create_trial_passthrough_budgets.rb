class CreateTrialPassthroughBudgets < ActiveRecord::Migration[7.1]
  def change
    create_table :trial_passthrough_budgets do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :name,            default: nil  # Passthrough Budget Name
      t.float     :max_amount,      default: 0.0  # Passthrough Budget Max Total Amount
      t.float     :monthly_amount,  default: 0.0  # Passthrough Budget Max Monthly Amount
      t.integer   :status,          default: 1    # Active/Disable
      t.integer   :sync,            default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

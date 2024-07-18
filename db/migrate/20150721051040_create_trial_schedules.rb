class CreateTrialSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :trial_schedules do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :name,              default: nil  # Template Schedule Name
      t.float     :tax_rate,          default: 0.0  # Payment Schedule Tax Rate
      t.float     :withholding_rate,  default: 0.0  # Payment Schedule Withholding Tax Rate
      t.float     :overhead_rate,     default: 0.0  # Payment Schedule Overhead Tax Rate
      t.float     :holdback_rate,     default: 0.0  # Payment Schedule Holdback Rate
      t.float     :holdback_amount,   default: nil  # Max Holdback Amount
      t.integer   :payment_terms,     default: 30   # Payment Terms
      t.integer   :status,            default: 1    # Active/Disable
      t.integer   :sync,              default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

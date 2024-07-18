class CreateSiteSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :site_schedules do |t|

      # Fields
      #----------------------------------------------------------------------
      t.boolean :mode,              default: true # Payment Schedule Mode(true: Editable, false: Payable)
      t.float   :tax_rate,          default: 0.0  # Payment Schedule Tax Rate
      t.float   :withholding_rate,  default: 0.0  # Payment Schedule Withholding Tax Rate
      t.float   :overhead_rate,     default: 0.0  # Payment Schedule Overhead Tax Rate
      t.float   :holdback_rate,     default: 0.0  # Payment Schedule Holdback Rate
      t.float   :holdback_amount,   default: nil  # Max Holdback Amount
      t.integer :payment_terms,     default: 30   # Payment Terms
      t.integer :status,            default: 1    # 0: Disabled(just same as Site), 1: Active
      t.integer :sync,              default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

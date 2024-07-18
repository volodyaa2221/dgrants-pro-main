class CreateTrialEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :trial_entries do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :event_id,      default: ""   # Trial Event ID
      t.integer   :type,          default: 0    # Payment Entry Type(same as Event Type), this is static or patient entry
      t.float     :amount,        default: 0.0  # Amount of Payment Entry
      t.float     :tax_rate,      default: 0.0  # Tax of Payment Entry
      t.float     :holdback_rate, default: 0.0  # Holdback Rate
      t.float     :advance,       default: 0.0  # Advance Amount of Payment Entry
      t.integer   :event_cap,     default: nil  # Event CAP
      t.datetime  :start_date,    default: nil  # Start Date of Payment Entry
      t.datetime  :end_date,      default: nil  # End Date of Payment Entry
      t.integer   :status,        default: 1    # Active/Disable
      t.integer   :sync,          default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

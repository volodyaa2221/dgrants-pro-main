class CreateSiteEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :site_entries do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :event_id,      default: ""   # Site Event ID(identical with Trial Event ID)
      t.integer   :type,          default: 0.0  # Payment Entry Type(same as Event Type), this is static or patient entry
      t.float     :amount,        default: 0.0  # Amount of Payment Entry
      t.float     :tax_rate,      default: 0.0  # Tax of Payment Entry
      t.float     :holdback_rate, default: 0.0  # Holdback Rate
      t.float     :advance,       default: 0.0  # Advance Amount of Payment Entry
      t.integer   :event_cap,     default: nil  # Event CAP
      t.integer   :event_count,   default: 0    # Event Count
      t.datetime  :start_date,    default: nil  # Start Date of Payment Entry
      t.datetime  :end_date,      default: nil  # End Date of Payment Entry
      t.integer   :status,        default: 2    # (0: Disabled, 1: Payable, 2: Editable)
      t.integer   :sync,          default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

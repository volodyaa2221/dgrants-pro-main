class CreateVpdEvents < ActiveRecord::Migration[7.1]

  def change
    create_table :vpd_events do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :event_id,    default: ""   # VPD EventType
      t.integer   :type,        default: 0    # VPD Event Type, this is single event as default
      t.string    :description, default: ""   # VPD Event Description
      t.integer   :days,        default: nil  # VPD Event days if dependency exists
      t.integer   :status,      default: 1    # Active/Disable
      t.integer   :sync,        default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

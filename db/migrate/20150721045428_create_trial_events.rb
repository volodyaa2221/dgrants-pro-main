class CreateTrialEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :trial_events do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :event_id,    default: ""   # Trial Event
      t.integer   :type,        default: 0    # Trial Event Type, this is single event as default
      t.string    :description, default: ""   # Trial Event Description
      t.integer   :days,        default: 0    # Trial Event days if dependency exists
      t.boolean   :editable,    default: true # Whether this Trial Event can be edited or not
      t.integer   :status,      default: 1    # Active/Disable
      t.integer   :sync,        default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null:false
    end
  end
end

class AddVpdEventReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :trial_events, [:id, :vpd_event_id]
  end
end

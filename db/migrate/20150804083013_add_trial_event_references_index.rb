class AddTrialEventReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :site_events, [:id, :trial_event_id]
  end
end

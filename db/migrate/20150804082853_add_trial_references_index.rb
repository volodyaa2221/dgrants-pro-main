class AddTrialReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :sites,           [:id, :trial_id]
    add_index :trial_events,    [:id, :trial_id]
    add_index :forecastings,    [:id, :trial_id]
    add_index :accounts,        [:id, :trial_id]
    add_index :trial_schedules, [:id, :trial_id]
  end
end

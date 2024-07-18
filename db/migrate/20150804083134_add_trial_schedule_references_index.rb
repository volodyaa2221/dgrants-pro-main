class AddTrialScheduleReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :trial_entries,             [:id, :trial_schedule_id]
    add_index :trial_passthrough_budgets, [:id, :trial_schedule_id]
  end
end

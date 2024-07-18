class AddTrialScheduleReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :trial_entries,             :trial_schedule, index: true
    add_reference :trial_passthrough_budgets, :trial_schedule, index: true
  end
end

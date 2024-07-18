class AddTrialScheduleReferenceIndexToSiteSchedule < ActiveRecord::Migration[7.1]
  def change
    add_index :site_schedules, [:id, :trial_schedule_id]
  end
end

class AddTrialScheduleReferenceToSiteSchedule < ActiveRecord::Migration[7.1]
  def change
    add_reference :site_schedules, :trial_schedule, index: true
  end
end

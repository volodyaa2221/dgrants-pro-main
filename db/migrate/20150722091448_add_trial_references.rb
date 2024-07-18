class AddTrialReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :sites,           :trial, index: true
    add_reference :trial_events,    :trial, index: true
    add_reference :forecastings,    :trial, index: true
    add_reference :accounts,        :trial, index: true
    add_reference :trial_schedules, :trial, index: true
  end
end

class AddTrialEventReferences < ActiveRecord::Migration[7.1]
  def change
    add_column  :trial_events, :dependency_id, :integer
    add_index   :trial_events, :dependency_id

    add_reference :site_events, :trial_event, index: true
  end
end

class AddVpdEventReferences < ActiveRecord::Migration[7.1]
  def change
    add_column  :vpd_events, :dependency_id, :integer
    add_index   :vpd_events, :dependency_id

    add_reference :trial_events, :vpd_event, index: true
  end
end

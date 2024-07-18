class RemoveCheckboxFieldsFromTrials < ActiveRecord::Migration[7.1]
  def change
    remove_column :trials, :event_need_approval
    remove_column :trials, :can_log_event
  end
end

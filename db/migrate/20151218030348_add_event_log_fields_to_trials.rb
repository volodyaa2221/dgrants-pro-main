class AddEventLogFieldsToTrials < ActiveRecord::Migration[7.1]
  def change
    add_column :trials, :can_log_event,       :boolean, default: true # Sites can log events (false: Then SU cannot log events)
    add_column :trials, :event_need_approval, :boolean, default: true # Logged events require TA/Monitor approval (true: Then TA/Monitor view of Event Log should show column 'Approved?' with 'Yes/No' switch)
  end
end

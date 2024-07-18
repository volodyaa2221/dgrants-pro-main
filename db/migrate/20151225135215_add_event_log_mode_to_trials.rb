class AddEventLogModeToTrials < ActiveRecord::Migration[7.1]
  def change
    add_column :trials, :event_log_mode, :integer, default: 1
  end
end

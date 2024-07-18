class ChangeDaysDefaultValueOfTrialEvent < ActiveRecord::Migration[7.1]
  def change
    change_column :trial_events, :days, :integer, default: 0    
  end
end

class AddOrderFieldToTrialEvent < ActiveRecord::Migration[7.1]
  def change
    add_column :trial_events, :order, :integer
  end
end

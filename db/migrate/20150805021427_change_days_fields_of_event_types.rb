class ChangeDaysFieldsOfEventTypes < ActiveRecord::Migration[7.1]
  def change
    change_column :vpd_events,    :days,  :integer, default: 0, null: false
    change_column :trial_events,  :days,  :integer, default: 0, null: false
  end
end

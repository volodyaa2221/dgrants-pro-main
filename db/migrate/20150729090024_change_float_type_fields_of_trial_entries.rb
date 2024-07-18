class ChangeFloatTypeFieldsOfTrialEntries < ActiveRecord::Migration[7.1]
  def change
    change_column :trial_entries, :amount,        :float, default: 0.0, null: false
    change_column :trial_entries, :tax_rate,      :float, default: 0.0, null: false
    change_column :trial_entries, :holdback_rate, :float, default: 0.0, null: false
    change_column :trial_entries, :advance,       :float, default: 0.0, null: false
  end
end

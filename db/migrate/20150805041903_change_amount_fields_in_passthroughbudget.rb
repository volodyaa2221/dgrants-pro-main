class ChangeAmountFieldsInPassthroughbudget < ActiveRecord::Migration[7.1]
  def change
    change_column :trial_passthrough_budgets, :max_amount,     :float, default: 0, null: false
    change_column :trial_passthrough_budgets, :monthly_amount, :float, default: 0, null: false
    change_column :site_passthrough_budgets,  :max_amount,     :float, default: 0, null: false
    change_column :site_passthrough_budgets,  :monthly_amount, :float, default: 0, null: false
  end
end

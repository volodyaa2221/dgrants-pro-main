class AddSitePassthroughBudgetReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :transactions, [:id, :site_passthrough_budget_id]
  end
end

class AddSitePassthroughBudgetReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :site_passthrough_budget, index: true
  end
end

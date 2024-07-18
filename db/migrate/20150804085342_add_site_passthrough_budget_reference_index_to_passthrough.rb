class AddSitePassthroughBudgetReferenceIndexToPassthrough < ActiveRecord::Migration[7.1]
  def change
    add_index :passthroughs, [:id, :site_passthrough_budget_id]
  end
end

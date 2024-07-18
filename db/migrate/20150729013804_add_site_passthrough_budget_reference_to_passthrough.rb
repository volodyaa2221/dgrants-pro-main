class AddSitePassthroughBudgetReferenceToPassthrough < ActiveRecord::Migration[7.1]
  def change
    add_reference :passthroughs, :site_passthrough_budget, index: true
  end
end

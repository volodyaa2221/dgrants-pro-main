class AddSiteReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :site_events,               [:id, :site_id]
    add_index :site_schedules,            [:id, :site_id]
    add_index :site_entries,              [:id, :site_id]
    add_index :transactions,              [:id, :site_id]
    add_index :invoices,                  [:id, :site_id]
    add_index :site_passthrough_budgets,  [:id, :site_id]
    add_index :passthroughs,              [:id, :site_id]
  end
end

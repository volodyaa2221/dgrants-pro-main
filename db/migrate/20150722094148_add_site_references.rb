class AddSiteReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :site_events,               :site, index: true
    add_reference :site_schedules,            :site, index: true
    add_reference :site_entries,              :site, index: true
    add_reference :transactions,              :site, index: true
    add_reference :invoices,                  :site, index: true
    add_reference :site_passthrough_budgets,  :site, index: true
    add_reference :passthroughs,              :site, index: true
    
    add_column  :sites, :main_site_id, :integer
    add_index   :sites, :main_site_id
  end
end

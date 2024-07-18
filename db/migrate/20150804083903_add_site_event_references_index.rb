class AddSiteEventReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :transactions, [:id, :site_event_id]
  end
end

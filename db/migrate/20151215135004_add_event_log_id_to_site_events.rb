class AddEventLogIdToSiteEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :site_events, :event_log_id, :string
  end
end

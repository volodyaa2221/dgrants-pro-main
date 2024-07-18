class AddSiteEventReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :site_event, index: true
  end
end

class AddSiteEntryReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :site_entry, index: true
  end
end

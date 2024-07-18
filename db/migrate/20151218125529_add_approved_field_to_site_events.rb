class AddApprovedFieldToSiteEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :site_events, :approved, :boolean, default: true # true: Approved by TA/Monitor otherwise false
  end
end

class AddOrderFieldToVpdEvent < ActiveRecord::Migration[7.1]
  def change
    add_column :vpd_events, :order, :integer
  end
end

class AddVpdReferenceIndexToRole < ActiveRecord::Migration[7.1]
  def change
    add_index :roles, [:id, :vpd_id]
  end
end

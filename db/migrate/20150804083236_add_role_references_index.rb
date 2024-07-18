class AddRoleReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :vpd_approvers, [:id, :role_id]
  end
end

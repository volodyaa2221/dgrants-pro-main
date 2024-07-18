class AddRoleReferences < ActiveRecord::Migration[7.1]
  def change
    add_column  :roles, :rolify_id,   :integer
    add_column  :roles, :rolify_type, :string
    add_index   :roles, :rolify_id

    add_reference :vpd_approvers, :role, index: true
  end
end

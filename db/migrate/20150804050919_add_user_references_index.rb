class AddUserReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :vpd_approvers, [:id, :user_id]
    add_index :roles,         [:id, :user_id]
    add_index :site_entries,  [:id, :user_id]
  end
end

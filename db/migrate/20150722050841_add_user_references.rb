class AddUserReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :vpd_approvers, :user, index: true
    add_reference :roles,         :user, index: true
    add_reference :site_entries,  :user, index: true
  end
end

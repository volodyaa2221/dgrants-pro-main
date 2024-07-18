class CreateVpdApprovers < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_approvers do |t|

      t.integer :type,    default: 0     # Approver Type(0: Tier 1 Approver, 1: Tier 2 Approver)
      t.integer :status,  default: 1     # Active/Disabled
      t.integer :sync,    default: 2     # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

class AddManagerToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :manager_id, :integer

    add_index :users, :manager_id
  end
end

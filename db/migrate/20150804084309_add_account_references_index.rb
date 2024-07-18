class AddAccountReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :posts,     [:id, :account_id]
    add_index :invoices,  [:id, :account_id]
  end
end

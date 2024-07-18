class AddAccountReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :posts,     :account, index: true
    add_reference :invoices,  :account, index: true
  end
end

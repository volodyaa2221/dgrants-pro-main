class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :post_id, default: nil  # Unique Post ID
      t.float   :amount,  default: 0    # Amount of Post
      t.integer :type,    default: 0    # 0: Credit, 1: Debit, 2: System Fee, 3: Invoice Payment,
      t.integer :sync,    default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

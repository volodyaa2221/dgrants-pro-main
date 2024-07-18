class CreatePassthroughs < ActiveRecord::Migration[7.1]
  def change
    create_table :passthroughs do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :budget_name, default: nil  # Passthrough Budget Name
      t.string    :description, default: nil  # Passthrough Description
      t.float     :amount,      default: 0    # Passthrough Amount
      t.datetime  :happened_at, default: nil  # Passthrough Date
      t.integer   :status,      default: 1    # (0: Disabled, 1: Pending, 2: Approved)
      t.integer   :sync,        default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

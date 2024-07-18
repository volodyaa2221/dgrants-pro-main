class AddVpdReferenceToRole < ActiveRecord::Migration[7.1]
  def change
    add_reference :roles, :vpd, index: true
  end
end

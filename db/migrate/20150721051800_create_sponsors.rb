class CreateSponsors < ActiveRecord::Migration[7.1]
  def change
    create_table :sponsors do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :name,    default: "" # Sponsor name
      t.integer :status,  default: 1  # Active/Disable

      t.timestamps null: false
    end
  end
end

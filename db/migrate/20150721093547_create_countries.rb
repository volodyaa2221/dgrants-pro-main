class CreateCountries < ActiveRecord::Migration[7.1]
  def change
    create_table :countries do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :name,    default: "" # Country Name
      t.string  :code,    default: "" # Country Code
      t.integer :status,  default: 1  # Active/Disable
      
      t.timestamps null: false
    end
  end
end

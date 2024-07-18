class AddCountryReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :vpd_countries, [:id, :country_id]
    add_index :sites,         [:id, :country_id]
  end
end

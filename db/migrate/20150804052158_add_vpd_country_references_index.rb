class AddVpdCountryReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :sites,         [:id, :vpd_country_id]
    add_index :forecastings,  [:id, :vpd_country_id]
  end
end

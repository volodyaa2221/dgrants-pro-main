class AddVpdCountryReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :sites,         :vpd_country, index: true
    add_reference :forecastings,  :vpd_country, index: true
  end
end

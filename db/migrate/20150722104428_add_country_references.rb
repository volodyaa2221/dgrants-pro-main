class AddCountryReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :vpd_countries, :country, index: true
    add_reference :sites, :country, index: true
  end
end

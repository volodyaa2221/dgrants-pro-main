class AddVpdSponsorReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :trials, [:id, :vpd_sponsor_id]
  end
end

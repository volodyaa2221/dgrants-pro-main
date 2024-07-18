class AddSponsorReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :vpd_sponsors,  [:id, :sponsor_id]
    add_index :trials,        [:id, :sponsor_id]
  end
end

class AddVpdSponsorReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :trials, :vpd_sponsor, index: true
  end
end

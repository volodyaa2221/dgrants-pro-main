class AddSponsorReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :vpd_sponsors,  :sponsor, index: true
    add_reference :trials,        :sponsor, index: true
  end
end

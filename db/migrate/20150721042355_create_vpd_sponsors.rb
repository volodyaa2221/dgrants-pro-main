class CreateVpdSponsors < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_sponsors do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :name,    default: ""   # VPD Sponsor name
      t.integer   :status,  default: 1    # Active/Disable
      t.integer   :sync,    default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

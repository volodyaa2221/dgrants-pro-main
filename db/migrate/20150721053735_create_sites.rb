class CreateSites < ActiveRecord::Migration[7.1]
  def change
    create_table :sites do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :name,              default: ""   # Site name
      t.string    :site_id,           default: ""   # Site Id
      t.integer   :site_type                        # Site type
      t.string    :city                             # City
      t.string    :state,             default: nil  # State
      t.string    :state_code                       # State code
      t.string    :address                          # Address
      t.string    :zip_code                         # Zip code
      t.string    :pi_first_name,     default: nil  # PI First Name
      t.string    :pi_last_name,      default: nil  # PI Last Name
      t.string    :pi_dea,            default: nil  # US DEA
      t.string    :drugdev_dea,       default: nil  # DrugDev DEA
      t.string    :country_name                     # Country name
      t.datetime  :start_date,        default: nil  # Real Site start date
      t.integer   :payment_verified,  default: 0    # Payment Verification(0: Empty, 1: Known Bad, 2: Presumed Good, 3: Known Good)
      t.integer   :status,            default: 1    # Active/Disable
      t.integer   :sync,              default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

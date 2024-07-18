class CreateVpds < ActiveRecord::Migration[7.1]
  def change
    create_table :vpds do |t|
  
      # Fields
      #----------------------------------------------------------------------
      t.string  :name,            default: ""     # VPD name
      t.float   :auto_amount,     default: 0.0    # VPD Auto-approval Threshold Amount(USD)
      t.float   :tier1_amount,    default: nil    # VPD Tier 1 Approval Threshold Amount(USD)
      t.string  :db_host,         default: nil    # Mysql Dump Server Url
      t.string  :db_name,         default: nil    # Mysql Dump Database Name
      t.string  :username,        default: nil    # Mysql Dump Username
      t.string  :password,        default: nil    # Mysql Dump Password
      t.string  :trial_dashboard, default: nil    # Trial Dashboard Base Url
      t.string  :site_dashboard,  default: nil    # Site Dashboard Base Url
      t.integer :status,          default: 1      # Active/Disabled
    
      t.timestamps null: false
    end
  end
end

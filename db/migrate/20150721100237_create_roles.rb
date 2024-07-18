class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|

      # Fields
      #----------------------------------------------------------------------
      t.integer   :role                                 # role - User's Position in Vpd or Trial or Site
      t.datetime  :invitation_sent_date,  default: nil  # Invitation Sent Date
      t.integer   :status,                default: 1    # Active/Disable
      t.integer   :sync,                  default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

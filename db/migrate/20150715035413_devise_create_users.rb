class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table(:users) do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      # t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      # t.string   :unlock_token # Only if unlock strategy is :email or :both
      # t.datetime :locked_at

      t.timestamps null: false

      # Custom Fields
      #----------------------------------------------------------------------
      t.string :first_name,         default: ""
      t.string :last_name,          default: ""
      t.string :title,              default: ""     # Not used right now
      t.string :prdisplay,          default: "P"    # Not used right now
      t.string :curr_pref,          default: "USD"  # Not used right now

      t.string :salutation,         default: "Mr."  # Prefix
      t.string :organization,       default: ""     # Organization 
      t.string :position,           default: ""     # Position
      t.string :phone,              default: ""     # Phone Number
      t.string :country,            default: ""     # Country
      
      t.integer :member_type,       default: 100    # Refer to above Role::ROLE
      t.integer :role_type,         default: 100    # Refer to above Role::ROLE(for mailer)
      t.integer :status,            default: 1      # Active/Disable
      
      t.string  :authentication_token 
      t.string  :profile_id             # profile Id of dProfile Profile table for session sharing
      t.string  :invited_to_type        # Trial or Site to which this user is invited
      t.integer :invited_to_id          # Id of Trial or Site to which this user is invited
      
      t.boolean :immediate_to_confirm,  default: false  # Flag to send email after creating a user
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    # add_index :users, :unlock_token,         unique: true
  end
end

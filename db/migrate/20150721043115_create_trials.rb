class CreateTrials < ActiveRecord::Migration[7.1]
  def change
    create_table :trials do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string  :title,               default: ""     # Trial Title
      t.string  :trial_id,            default: nil    # Trial ID
      t.string  :ctgov_nct,           default: nil    # CT.gov NCT
      t.integer :indication,          default: nil    # Indication for Trial (type of disease)
      t.integer :phase,               default: nil    # Phase for Trial
      t.integer :status,              default: 1      # Active / Disable
      t.integer :max_patients,        default: nil    # Maximum Number of Patients
      t.integer :real_patients_count, default: 0      # Real patients count
      t.integer :patients_count,      default: 0      # Forecasting patients count(Sum of real and forecasting)
      t.boolean :should_forecast,     default: false  # If trial should forecast(is forecasting) or not
      t.boolean :forecasting_now,     default: false  # Indicate if trial is forecasting now or not
      t.integer :sync,                default: 2      # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

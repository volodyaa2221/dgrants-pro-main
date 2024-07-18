class CreateForecastings < ActiveRecord::Migration[7.1]
  def change
    create_table :forecastings do |t|

      # Fields
      #----------------------------------------------------------------------
      t.datetime  :est_start_date               # Estimated Start Date
      t.float     :recruitment_rate, default: 0 # Forecast Site Recruitment Rate
      t.integer   :sync, default: 2             # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

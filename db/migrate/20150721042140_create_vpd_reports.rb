class CreateVpdReports < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_reports do |t|

      # Fiedls
      #----------------------------------------------------------------------
      t.string  :name,    default: nil  # Report Name
      t.string  :url,     default: nil  # Report Embed Url
      t.integer :status,  default: 1    # Active/Disable

      t.timestamps null: false
    end
  end
end

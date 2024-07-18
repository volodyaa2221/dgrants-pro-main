class CreateVpdMailTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :vpd_mail_templates do |t|

      # Fields
      #----------------------------------------------------------------------
      t.integer :type
      t.string  :subject
      t.string  :body
      t.integer :status,  default: 1 # Active/Disable

      t.timestamps null: false
    end
  end
end

class ChangeBodyTypeInVpdMailTemplate < ActiveRecord::Migration[7.1]
  def change
    change_column :vpd_mail_templates, :body, :text
  end
end

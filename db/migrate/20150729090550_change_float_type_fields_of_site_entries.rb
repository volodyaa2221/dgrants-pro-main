class ChangeFloatTypeFieldsOfSiteEntries < ActiveRecord::Migration[7.1]
  def change
    change_column :site_entries, :amount,        :float, default: 0.0, null: false
    change_column :site_entries, :tax_rate,      :float, default: 0.0, null: false
    change_column :site_entries, :holdback_rate, :float, default: 0.0, null: false
    change_column :site_entries, :advance,       :float, default: 0.0, null: false
  end
end

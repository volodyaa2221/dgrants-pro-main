class AddVpdCurrencyReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :trial_schedules, [:id, :vpd_currency_id]
    add_index :site_schedules,  [:id, :vpd_currency_id]
    add_index :invoices,        [:id, :vpd_currency_id]
  end
end

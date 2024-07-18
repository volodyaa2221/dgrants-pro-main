class AddCurrencyReferencesIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :vpd_currencies,  [:id, :currency_id]
    add_index :trial_schedules, [:id, :currency_id]
    add_index :site_schedules,  [:id, :currency_id]
    add_index :invoices,        [:id, :currency_id]
  end
end

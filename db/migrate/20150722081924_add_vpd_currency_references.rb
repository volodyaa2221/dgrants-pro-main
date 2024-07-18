class AddVpdCurrencyReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :trial_schedules, :vpd_currency, index: true
    add_reference :site_schedules,  :vpd_currency, index: true
    add_reference :invoices,        :vpd_currency, index: true
  end
end

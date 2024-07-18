class AddCurrencyReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :vpd_currencies,  :currency, index: true
    add_reference :trial_schedules, :currency, index: true
    add_reference :site_schedules,  :currency, index: true
    add_reference :invoices,        :currency, index: true
  end
end

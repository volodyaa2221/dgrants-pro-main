class AddVpdReferences < ActiveRecord::Migration[7.1]
  def change
    add_reference :accounts,                  :vpd, index: true
    add_reference :posts,                     :vpd, index: true
    add_reference :vpd_sponsors,              :vpd, index: true
    add_reference :vpd_countries,             :vpd, index: true
    add_reference :vpd_currencies,            :vpd, index: true
    add_reference :vpd_mail_templates,        :vpd, index: true
    add_reference :vpd_approvers,             :vpd, index: true
    add_reference :vpd_reports,               :vpd, index: true
    add_reference :vpd_ledger_categories,     :vpd, index: true
    add_reference :vpd_events,                :vpd, index: true
    add_reference :trials,                    :vpd, index: true
    add_reference :trial_schedules,           :vpd, index: true
    add_reference :trial_events,              :vpd, index: true
    add_reference :trial_entries,             :vpd, index: true
    add_reference :trial_passthrough_budgets, :vpd, index: true
    add_reference :forecastings,              :vpd, index: true
    add_reference :sites,                     :vpd, index: true
    add_reference :site_schedules,            :vpd, index: true
    add_reference :site_events,               :vpd, index: true
    add_reference :site_entries,              :vpd, index: true
    add_reference :site_passthrough_budgets,  :vpd, index: true
    add_reference :passthroughs,              :vpd, index: true
    add_reference :invoices,                  :vpd, index: true
    add_reference :transactions,              :vpd, index: true
  end
end

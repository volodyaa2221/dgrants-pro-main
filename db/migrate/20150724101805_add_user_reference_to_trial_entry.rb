class AddUserReferenceToTrialEntry < ActiveRecord::Migration[7.1]
  def change
    add_reference :trial_entries, :user, index: true
  end
end

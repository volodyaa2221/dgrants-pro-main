class AddUserReferenceIndexToTrialEntry < ActiveRecord::Migration[7.1]
  def change
    add_index :trial_entries, [:id, :user_id]
  end
end

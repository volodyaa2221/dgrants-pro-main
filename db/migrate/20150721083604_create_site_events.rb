class CreateSiteEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :site_events do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :event_id,          default: ""       # Site Event ID(identical with Trial Event ID)
      t.integer   :type,              default: 0        # Site Event Type, this is single event as default
      t.string    :description,       default: ""       # Site Event Description
      t.string    :patient_id,        default: nil      # Patient ID whom site event applies to, if the event type is patient event
      t.datetime  :happened_at,       default: nil      # Date when Site Event is happened
      t.string    :happened_at_text,  default: nil      # Date String of happened_at(for search)
      t.string    :source,            default: "Manual" # Site Event Source(API, Manual, Cron Job)
      t.integer   :status,            default: 1        # Status & Verified(active/disable)
      t.integer   :sync,              default: 2        # 0 : synced, 1 : updated, 2 : created
      t.string    :author,            default: nil      # User who logged the site event log
      t.string    :co_author,         default: nil      # Co Author User who signed the site event log

      t.timestamps null: false
    end
  end
end

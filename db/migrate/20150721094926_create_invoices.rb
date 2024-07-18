class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :invoice_no,    default: nil  # Unique Invoice ID
      t.float     :amount,        default: 0.0  # Amount(Payable) of Invoice
      t.float     :included_tax,  default: 0.0  # Included Tax Amount of Invoice
      t.float     :withholding,   default: 0.0  # Withholding
      t.float     :overhead,      default: 0.0  # Overhead
      t.float     :usd_rate,      default: 1.0  # USD Rate
      t.datetime  :pay_at,        default: nil  # Pay at
      t.datetime  :sent_at,       default: nil  # Sent at to Tipalti(Tipalti Pending)      
      t.integer   :type,          default: 0    # Invoice Type(0: Normal Invoice, 1: Remit Withholding Invoice)
      t.string    :pi_dea,        default: nil  # US DEA
      t.string    :drugdev_dea,   default: nil  # DrugDev DEA
      t.integer   :status,        default: 0    # 0:Needs Approval, 1:Approved, 2:In Progress, 3: Pending Queued, 4:Paid Offline, 5:Rejected, 6:Successful, 7:Deleted
      t.integer   :sync,          default: 2    # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

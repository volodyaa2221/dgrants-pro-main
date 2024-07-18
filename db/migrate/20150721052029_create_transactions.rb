class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|

      # Fields
      #----------------------------------------------------------------------
      t.string    :transaction_id,  default: nil      # Unique Transaction ID
      t.integer   :type,            default: 0        # 0: Static Event, 1: Patient Event, 2: Passthrough, 3: Holdback Release, 4: Withholding Release
      t.string    :type_id,         default: ""       # Site Event ID/Passthrough Budget Name
      t.string    :patient_id,      default: nil      # Patient ID whom site event applies to, if the event type is patient event
      t.datetime  :happened_at,     default: nil      # Date when Event Log/Passthrough is happened
      t.boolean   :payable,         default: false    # True: Payable, False: Over Cap(Non Payable)
      t.float     :amount,          default: 0.0      # Amount of Transaction
      t.float     :tax,             default: 0.0      # Tax Amount(amount * tax)
      t.float     :earned,          default: 0.0      # Earned Amount(amount + tax)
      t.float     :advance,         default: 0.0      # Advance Amount of Transaction
      t.float     :retained_amount, default: 0.0      # Retained(Holdback) Amount(amount * holdback_rate)
      t.float     :retained_tax,    default: 0.0      # Retained(Holdback) Tax Amount(tax * holdback_rate)
      t.float     :retained,        default: 0.0      # Retained Amount(retained_amount + retained_tax)
      t.float     :withholding,     default: 0.0      # Withholding Amount(this is set only if transaction is withholding release)
      t.float     :usd_rate,        default: 1.0      # USD Rate
      t.boolean   :paid,            default: false    # True: Paid, False: Unpaid
      t.string    :source,          default: "Manual" # Manual: Real Transaction, Forecasting: Forecast Transaction
      t.integer   :status,          default: 2        # 0: Disabled(reversal), 1: Reversed(already reversed), 2: Normal
      t.integer   :included,        default: 1        # 0: Excluded, 1: Included (Excluded transactions are not included in the current invoice submission)
      t.integer   :sync,            default: 2        # 0 : synced, 1 : updated, 2 : created

      t.timestamps null: false
    end
  end
end

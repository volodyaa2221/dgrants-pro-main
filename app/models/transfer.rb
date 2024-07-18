class Transfer < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  # Associations
  #----------------------------------------------------------------------
  belongs_to :account
  
  has_many   :invoices

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :amount, :type
  validates_uniqueness_of :transfer_id

  # Scopes
  #----------------------------------------------------------------------
  # scope :activated_transfers, -> {where(status: 1)}

  # Callbacks
  #----------------------------------------------------------------------

  # Collection methods
  #----------------------------------------------------------------------

  # Attribute methods
  #----------------------------------------------------------------------

  # Callback methods
  #----------------------------------------------------------------------

  # Private methods
  #----------------------------------------------------------------------
  private
end
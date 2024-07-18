class VpdReport < ActiveRecord::Base

  # Associations
  #----------------------------------------------------------------------
  belongs_to :vpd

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :name, :url
  validates_uniqueness_of :name, :url, case_sensitive: true, scope: :vpd_id
end
class Country < ActiveRecord::Base

  # Associations
  #----------------------------------------------------------------------
  has_many :vpd_countries
  has_many :sites

  # Validations
  #----------------------------------------------------------------------
  validates :code, presence: true
  validates :name, presence: true, uniqueness: true

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_countries, -> {where(status: 1)}

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Get all trials of this country
  def trials
    trial_ids = Site.where(country: self, status: 1).map(&:trial_id).uniq
    Trial.where(id: trial_ids, status: 1)
  end
end

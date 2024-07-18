class Sponsor < ActiveRecord::Base

  # Associations
  #----------------------------------------------------------------------
  has_many :vpd_sponsors
  has_many :trials

  # Validations
  #----------------------------------------------------------------------
  validates_presence_of :name
  validates_uniqueness_of :name, case_sensitive: false

  # Scopes
  #----------------------------------------------------------------------
  scope :activated_sponsors, -> { where(status: 1) }

  # Callbacks
  #----------------------------------------------------------------------
  after_update :update_vpd_sponsors

  # Collection methods
  #----------------------------------------------------------------------
  # Public: Get all sites of this sponsor
  def sites
    trial_ids = Trial.where(sponsor: self, status: 1).map(&:id).uniq
    Site.where(trial_id: trial_ids, status: 1)
  end

  # Private methods
  #----------------------------------------------------------------------
  private

  # Private: Update VPD Sponsors when the name is changed
  def update_vpd_sponsors
    sponsor = self
    if sponsor.changed.include?("name")
      vpd_sponsors.each {|vpd_sponsor| vpd_sponsor.update_attributes(name: sponsor.name)}
    end
  end
end
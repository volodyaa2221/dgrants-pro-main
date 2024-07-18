# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

p "- Clear all jobs"
Delayed::Job.destroy_all

p "- Destroy Country"
Country.destroy_all
p "- Destroy Currency"
Currency.destroy_all
p "- Destroy Sponsor"
Sponsor.destroy_all

p "- Destroy Vpd"
Vpd.destroy_all
p "- Destroy VpdCountry"
VpdCountry.destroy_all
p "- Destroy VpdCurrency"
VpdCurrency.destroy_all
p "- Destroy VpdMailTemplate"
VpdMailTemplate.destroy_all
p "- Destroy VpdSponsor"
VpdSponsor.destroy_all
p "- Destroy VpdEvent"
VpdEvent.destroy_all

p "- Destroy Trial"
Trial.destroy_all
p "- Destroy Forecasting"
Forecasting.destroy_all
p "- Destroy TrialSchedule"
TrialSchedule.destroy_all
p "- Destroy TrialEvent"
TrialEvent.destroy_all
p "- Destroy TrialEntry"
TrialEntry.destroy_all
p "- Destroy TrialPassthroughBudget"
TrialPassthroughBudget.destroy_all

p "- Destroy Site"
Site.destroy_all
p "- Destroy SiteSchedule"
SiteSchedule.destroy_all
p "- Destroy SiteEvent"
SiteEvent.destroy_all
p "- Destroy SiteEntry"
SiteEntry.destroy_all
p "- Destroy SitePassthroughBudget"
SitePassthroughBudget.destroy_all
p "- Destroy Passthrough"
Passthrough.destroy_all
p "- Destroy Transaction"
Transaction.destroy_all
p "- Destroy Invoice"
Invoice.destroy_all
p "- Destroy InvoiceFile"
InvoiceFile.destroy_all
p "- Destroy Transfer"
Transfer.destroy_all

p "- Destroy Account"
Account.destroy_all
p "- Destroy User"
User.destroy_all
p "- Destroy Role"
Role.destroy_all

p "- Create Super admin for dGrants"
user = User.where(email: Dgrants::Application::CONSTS[:contact_email]).first
unless user.present?
  admin = User.create(email: Dgrants::Application::CONSTS[:contact_email], password: "admin321",
    password_confirmation: "admin321", member_type: Role::ROLE[:super_admin], 
    first_name: "Ping", last_name: "Ahn", confirmed_at: Time.now)
  admin = User.find(admin.id.to_s)
  admin.confirm!
end

p "- Create DrugDev account"
Account.create(ref_id: Account::DRUGDEV_REFID, vpd_name: "DRUGDEV")

p "- Import all countries"
count = 0
Carmen::Country.all.select do |country|
  country_object = Country.new(name: country.name, code: country.code)
  if country_object.save
    count += 1
  else
    p "    #{country.errors.full_messages.first} for #{country.name}"
  end
end
p "  #{count} countries imported"

p "- Import all sponsors"
count = 0
csv_file_path = File.join(File.dirname(__FILE__), "res/sponsors.csv")
CSV.foreach(csv_file_path, headers: false) do |row|
  sponsor = Sponsor.new(name: row[0])
  if sponsor.save
    count += 1
  else
    p "    #{sponsor.errors.full_messages.first} for #{sponsor.name}"
  end
end
p "  #{count} sponsors imported"
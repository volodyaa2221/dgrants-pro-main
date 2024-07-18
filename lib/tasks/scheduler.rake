# desc "This task is called by the Heroku scheduler add-on"
task :currency_update_rates => :environment do
  puts "Starting updating exchange rates..."
  Currency.update_rates
  puts "done."
end

# desc "This task is called by the Heroku scheduler add-on"
task :mongo_sql_dump => :environment do
  Vpd.mongo_to_mysql_dump
end

# desc "This task is called by the Heroku scheduler add-on"
task :check_overdue_invoices do
  Site.check_overdue_invoices if Time.now.day == 1
end
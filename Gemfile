source 'https://rubygems.org'

ruby '3.3.4'

gem 'rails'

# Use mysql as the database for Active Record
gem 'mysql2'

# for Web server
gem 'puma'
gem 'rack-timeout'

gem 'roo'
gem 'nokogiri'
gem 'binding_of_caller'

gem 'jquery-rails'
gem 'turbolinks'
gem 'jbuilder'

gem 'haml-rails'
gem 'haml2slim'
gem 'html2haml'
gem 'parsley-rails'
gem 'bootstrap-sass'
gem 'bootstrap-datepicker-rails'
gem 'autoprefixer-rails'
gem 'simple_form'
# Indicator for all ajax call events
gem 'spinjs-rails'

gem 'devise'

gem 'newrelic_rpm' # for project diagnostics

# Mailer gem
gem 'postmark-rails'

# gem "mongoid-paperclip", :require => "mongoid_paperclip" # related to Amazon
gem 'paperclip'
gem 'aws-sdk'
gem 'remotipart' # for Ajax File Upload

gem 'will_paginate'

# related to country, state and city
gem 'country_select'
gem 'carmen'
gem 'carmen-rails'
gem 'geoip'

gem 'lazy_high_charts'

# for data tables
gem 'jquery-datatables-rails'
gem 'jquery-ui-rails'

# for background asynchronous processing(http://blog.andolasoft.com/2013/04/4-simple-steps-to-implement-delayed-job-in-rails.html)
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'daemon-spawn'

# for External APIs
gem 'rest-client'

# Hash for API
gem 'hashids'

gem 'rails-upgrade'

group :assets do
  gem 'sass-rails'
  gem 'uglifier'
  gem 'coffee-rails'
  gem 'therubyracer', :platforms => :ruby
end

group :development do
  gem 'better_errors'  
  gem 'hub', :require=>nil
  gem 'rails_layout'
  # gem 'debugger'
  gem 'letter_opener' # for checking email template in local development environment
end

group :development, :test do
  gem 'factory_bot'
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'rspec-rails'
  gem 'railroady' # for making svg diagram
  gem 'whenever', :require => false # for cron job
end

group :test do
  gem 'capybara'
  gem 'database_cleaner'
  gem 'email_spec'
  # gem 'mongoid-rspec', '>= 1.10.0'
end

group :production, :heroku do
  gem 'rails_12factor'
end
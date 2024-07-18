require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'csv'
require "will_paginate/array"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dgrants
  class Application < Rails::Application
    CONSTS = {
      app_name:         "dGrants",
      app_host:         "https://dgrants.drugdev.com",
      contact_email:    "dgrants@drugdev.com",
      cookie_name:       "_drugdev",
      expire_time:      30.minutes,

      dev_host:         "http://192.168.1.122:4020",
      dev_ip:           "192.168.1.122",
      dev_port:         "4020"
    }

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    require Rails.root.join("lib/custom_public_exceptions")
    config.exceptions_app = CustomPublicExceptions.new(Rails.public_path)

    config.before_configuration do
      env_file = File.join(Rails.root, 'config', 'app_env.yml')
      YAML.load(File.open(env_file)).each do |key, value|
        ENV[key.to_s] = value
      end if File.exist?(env_file)
    end
  end
end

Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout, service_timeout: 300

# Unregistering the observer to disable the logging
Rack::Timeout.unregister_state_change_observer(:logger)
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 2)
threads threads_count, threads_count

# rackup      DefaultRackup
port        ENV['PORT']     || 4020
environment ENV.fetch('RACK_ENV') { 'development' }
preload_app!

on_worker_boot do
  # worker specific setup
  ActiveRecord::Base.establish_connection
end



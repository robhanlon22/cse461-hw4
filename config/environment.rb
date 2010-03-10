# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.gem 'uuid'

  require 'lib/string_extensions'
  require 'lib/io_extensions'
  require 'socket'
end

Dir.glob(File.join(RAILS_ROOT, 'app', 'jobs', '*.rb')).each do |job|
  require job
end

Delayed::Job.enqueue(Broadcaster.new(PORT))
Delayed::Job.enqueue(BroadcastDelegator.new)

# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.gem 'uuid'
  config.gem 'yajl-ruby', :lib => 'yajl'

  require 'lib/elmo'
  require 'lib/io_extensions'
  require 'lib/string_extensions'

  require 'lib/anti_entropy_client'
  require 'lib/anti_entropy_server'
  require 'lib/broadcast_delegator'
  require 'lib/broadcaster'

  require 'socket'
end

Thread.new do
  BroadcastDelegator.new.run
end

Thread.new do
  Broadcaster.new(PORT).run
end

Thread.new do
  AntiEntropyServer.new(PORT).run
end

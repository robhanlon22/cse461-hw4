$LOAD_PATH.unshift(File.join(RAILS_ROOT, 'app', 'jobs'))

require 'broadcaster'
require 'broadcast_delegator'
require 'anti_entropy_server'

Delayed::Job.enqueue(Broadcaster.new(PORT))
Delayed::Job.enqueue(AntiEntropyServer.new(PORT))
Delayed::Job.enqueue(BroadcastDelegator.new)

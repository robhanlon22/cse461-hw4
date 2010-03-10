Dir.glob(File.join(RAILS_ROOT, 'app', 'jobs', '*.rb')).each do |job|
  require job
end

Delayed::Job.enqueue(Broadcaster.new(PORT))
Delayed::Job.enqueue(AntiEntropyServer.new(PORT))
Delayed::Job.enqueue(BroadcastDelegator.new)
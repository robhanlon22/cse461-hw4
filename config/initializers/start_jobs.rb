Dir.glob(File.join(RAILS_ROOT, 'app', 'jobs', '*.rb')).each do |job|
  require job
end

Delayed::Job.enqueue(Broadcaster.new(PORT, Rails.logger))
Delayed::Job.enqueue(AntiEntropyServer.new(PORT, Rails.logger))
Delayed::Job.enqueue(BroadcastDelegator.new(Rails.logger))

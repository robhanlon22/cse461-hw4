class BroadcastDelegator
  def run
    # We'll use a hash to make sure we never spin up more than one client per
    # server IP address.
    @clients = {}
    @client_mutex = Monitor.new # Ruby Monitors are reentrant; Mutexes are not
    
    BasicSocket.do_not_reverse_lookup = true
    logger.info("#{self.class}-#{self.object_id}: Listening for broadcasts...")
    sock = UDPSocket.new
    sock.bind('0.0.0.0', 30000)
    loop do
      logger.info("#{self.class}-#{self.object_id}: Waiting for broadcast data...")
      data, addr = sock.recvfrom(1024)
      logger.info("#{self.class}-#{self.object_id}: Received broadcast data, data = #{data}, from #{addr[2]}")
      
      # Lock down the @clients hash until we know we've added the mapping
      @client_mutex.synchronize do
        if valid?(data) and not @clients.has_key?(addr[2])
          logger.info("#{self.class}-#{self.object_id}: data was valid, starting anti-entropy client...")
          data = data.split
          address = addr[2]
          
          # Create a new client to connect to remote instance, add to mapping
          new_client = AntiEntropyClient.new(address, data.last.to_i)
          @clients[address] = new_client
          
          # Start a new thread for the new client (this thread does NOT have
          # the lock on @client_mutex).
          Thread.new do            
            begin
              new_client.run
            ensure
              # Make sure that when the thread terminates, we remove the
              # mapping for this remote instance.
              @client_mutex.synchronize { @clients.delete(address) }
            end
          end
        end
      end
      
      # Is this good? Our thinking was that updating more often would be a waste.      
      sleep 1
    end
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end

  def valid?(data)
    data =~ /^flickr\s+\d{1,5}\s*$/i
    logger.info("#{self.class}-#{self.object_id}: Is the broadcast data valid: #{data ? 'yes' : 'no' }")
  end
end

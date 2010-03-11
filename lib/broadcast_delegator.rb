class BroadcastDelegator
  def run
    # We'll use a hash to make sure we never spin up more than one client per
    # server IP address.
    @clients = {}
    
    BasicSocket.do_not_reverse_lookup = true
    logger.info("Listening for broadcasts...")
    sock = UDPSocket.new
    sock.bind('0.0.0.0', 30000)
    loop do
      logger.info("Waiting for data...")
      data, addr = sock.recvfrom(1024)
      logger.info("Received data.")
      logger.info("data = #{data}, from #{addr[2]}")
      if valid?(data) and not @clients.has_key?(addr[2])
        logger.info("data was valid, starting anti-entropy client...")
        data = data.split
        Thread.new do
          address = addr[2]
          new_client = AntiEntropyClient.new(address, data.last.to_i)
          @clients[address] = new_client
          begin
            new_client.run
          ensure
            @clients.delete(address)
          end
        end
        sleep 1
      end
    end
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end

  def valid?(data)
    data =~ /^flickr \d{1,5}$/
    logger.info("#{self.class}-#{self.object_id}: Is the broadcast data valid: #{data ? 'yes' : 'no' }")
  end
end

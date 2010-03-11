class BroadcastDelegator
  def run
    BasicSocket.do_not_reverse_lookup = true
    logger.info("Listening for broadcasts...")
    sock = UDPSocket.new
    sock.bind('0.0.0.0', 30000)
    loop do
      logger.info("Waiting for data...")
      data, addr = sock.recvfrom(1024)
      logger.info("Received data.")
      logger.info("data = #{data}, from #{addr[2]}")
      if valid?(data)
        logger.info("data was valid, starting anti-entropy client...")
        data = data.split
        Thread.new do
          AntiEntropyClient.new(addr[2], data.last.to_i)
        end
      end
    end
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end

  def valid?(data)
    data =~ /^flickr \d{1,5}$/
  end
end

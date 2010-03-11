Broadcaster = Struct.new(:tcp_port) do
  def run
    logger.info("Opening UDP socket")
    sock = UDPSocket.new
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    logger.info("Opened UDP socket")
    logger.info("Broadcasting flickr #{tcp_port}")
    loop do
      sock.send("flickr #{tcp_port}", 0, '<broadcast>', 30000)
      sleep 5
    end
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end
end

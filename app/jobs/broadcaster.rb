require 'socket'

Broadcaster = Struct.new(:tcp_port) do
  def perform
    logger.info("Opening UDP socket")
    sock = UDPSocket.new
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    logger.info("Opened UDP socket")
    logger.info("Broadcasting flickr #{@tcp_port}")
    sock.send("flickr #{@tcp_port}", 0, '<broadcast>', 30000)
  rescue Exception => e
    logger.warn(e)
  ensure
    sock.close
    logger.info("Sleeping for 5 seconds")
    sleep 5
    Delayed::Job.enqueue(new(@tcp_port))
  end
end

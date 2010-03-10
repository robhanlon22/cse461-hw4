require 'socket'

Broadcaster = Struct.new(:tcp_port) do
  def logger
    Delayed::Worker.logger
  end

  def perform
    sock = nil
    begin
      logger.info("Opening UDP socket")
      sock = UDPSocket.new
      sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      logger.info("Opened UDP socket")
      logger.info("Broadcasting flickr #{tcp_port}")
      sock.send("flickr #{tcp_port}", 0, '<broadcast>', 30000)
    rescue Exception => e
      logger.warn(e)
    ensure
      sock.close rescue Exception
      logger.info("Sleeping for 5 seconds")
      sleep 5
      Delayed::Job.enqueue(Broadcaster.new(tcp_port))
    end
  end
end

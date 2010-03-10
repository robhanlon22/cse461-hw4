require 'socket'

Broadcaster = Struct.new(:tcp_port) do
  def perform
    sock = UDPSocket.new
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    loop do
      sock.send("flickr #{@tcp_port}", 0, '<broadcast>', 30000)
      sleep 5
    end
  rescue
    Delayed::Job.enqueue(Broadcaster.new(@tcp_port))
  end
end

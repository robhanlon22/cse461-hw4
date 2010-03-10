require 'socket'

AntiEntropyClient = Struct.new(server_addr, tcp_port) do
  def perform
    sock = TCPSocket.new(@server_addr, @tcp_port)
    sock.write(Log.get_version_vector.prefix_with_length!)
  end
end

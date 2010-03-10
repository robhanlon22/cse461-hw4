require 'socket'

AntiEntropyClient = Struct.new(server_addr, tcp_port) do
  def perform
    sock = TCPSocket.new(@server_addr, @tcp_port)
    sock.puts("version_vector")
  end
end

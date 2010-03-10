require 'socket'

AntiEntropyServerJob = Struct.new(:tcp_port) do
  def perform
    server = TCPServer.new(@tcp_port)
    loop do
      client = server.accept
      # wait for vector
        # vector received =>
          # validate_vector
    end
  end
end

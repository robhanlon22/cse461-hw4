require 'socket'
require 'yajl'

AntiEntropyClient = Struct.new(server_addr, tcp_port) do
  ACK = {"OP" => "ACK"}.to_json.prefix_with_length!

  def perform
    sock = TCPSocket.new(@server_addr, @tcp_port)
    sock.write(Log.get_version_vector.prefix_with_length!)
    wait_for_ack
    raw_logs = sock.read
    log_hashes = split_logs(raw_logs)

    Log.add_logs(log_hashes)
  end

  private
  def split_logs(raw_logs)
    log_hashes = []
    io = StringIO.new(raw_logs)
    until io.eof?
      length = io.read_length_field
      log_hashes << Yajl::Parser.parse(io.read(length))
    end
    log_hashes
  end

  def wait_for_ack
    until sock.eof?
      length = sock.read_length_field
      ack = Yajl::Parser.parse(sock.read(length))

      next unless ack["OP"] == "ACK"
      abort ack["MSG"] if ack["FLG"] == "ERROR"
      break
    end
  end

  def send_ack(sock)
    sock.write(ACK)
  end
end

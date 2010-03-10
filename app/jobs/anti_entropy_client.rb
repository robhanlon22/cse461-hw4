require 'socket'
require 'yajl'
require 'activesupport'

AntiEntropyClient = Struct.new(:server_addr, :tcp_port, :logger) do
  include Elmo

  def perform
    sock = TCPSocket.new(@server_addr, @tcp_port)
    send_version_vector(sock)
    wait_for_ack(sock)
    raw_logs = grab_raw_logs(sock)
    log_hashes = split_logs(raw_logs)
    Log.add_logs(log_hashes)
  end

  private
  def send_version_vector(sock, t = 5)
    version_vector = Log.get_version_vector
    Timeout.timeout(t) { sock.write(version_vector.prefix_with_length!) }
  end

  def grab_raw_logs(sock, t = 5)
    raw_logs = ""
    until sock.eof?
      Timeout.timeout(t) do
        length = sock.read_length_field
        raw_logs << sock.read(length)
      end
      send_ack(sock)
    end
    raw_logs
  end

  def split_logs(raw_logs)
    log_hashes = []
    io = StringIO.new(raw_logs)
    until io.eof?
      length = io.read_length_field
      log_hashes << Yajl::Parser.parse(io.read(length))
    end
    log_hashes
  end
end

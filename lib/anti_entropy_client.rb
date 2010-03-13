AntiEntropyClient = Struct.new(:server_addr, :tcp_port) do
  include Elmo
  
  READ_BUFFER_SIZE = 1024

  def run
    logger.info("#{self.class}-#{self.object_id}: started, opening TCP socket to #{server_addr}:#{tcp_port}")
    sock = TCPSocket.new(server_addr, tcp_port)

    send_version_vector(sock)
    logger.info("#{self.class}-#{self.object_id}: about to wait for an ACK of version vector")
    wait_for_ack(sock, 5, logger)
    raw_logs = grab_raw_logs(sock)
    log_hashes = split_logs(raw_logs)
    unless log_hashes.empty?
      logger.info("#{self.class}-#{self.object_id}: Received #{log_hashes.size} logs to add.")
      Log.add_logs(log_hashes)
      Log.replay
    else
      logger.info("#{self.class}-#{self.object_id}: Server does not have any missing logs for us.")
    end
  rescue Exception => e
    logger.warn("#{self.class}-#{self.object_id}: #{e} -- #{e.message}")
    logger.warn("#{self.class}-#{self.object_id}: #{e.backtrace * "\n"}")
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end

  def send_version_vector(sock, t = 10)
    version_vector = Log.get_version_vector.to_json
    logger.info("#{self.class}-#{self.object_id}: sending version vector #{version_vector}")
    Timeout.timeout(t) { sock.write(version_vector.prefix_with_length!) }
  end

  def grab_raw_logs(sock, t = 10)
    logger.info("#{self.class}-#{self.object_id}: grabbing raw logs...")
    raw_logs = []
    until sock.eof?
      length, bytes_read = nil, 0
      Timeout::timeout(t) { length = sock.read_length_field }
      
      # We want to time-out when no progress is made, but not time-out when
      # reading a large message, so we need to read a chunk at a time.
      chunks = []
      while bytes_read < length
        # Read up to READ_BUFFER_SIZE bytes at a time
        bytes_to_read = [(length - bytes_read), READ_BUFFER_SIZE].min 
        
        Timeout::timeout(t) { chunks << sock.read(bytes_to_read) }
        
        bytes_read += bytes_to_read
      end
      send_ack(sock, :FLG => :success)
    end
    logger.info("#{self.class}-#{self.object_id}: raw logs are #{raw_logs * "\n"}")
    raw_logs
  end

  def split_logs(raw_logs)
    raw_logs.inject([]) { |m, raw| m << Yajl::Parser.parse(raw) }
  end
end

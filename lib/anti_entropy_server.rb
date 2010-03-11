AntiEntropyServer = Struct.new(:tcp_port) do
  include Elmo

  def run
    logger.info("#{self.class}-#{self.object_id}: starting TCP server on port #{tcp_port}")
    server = TCPServer.new(tcp_port)
    loop do
      client = server.accept
      logger.info("#{self.class}-#{self.object_id}: accepted client")
      begin
        handle_client(client)
      rescue Exception => e
        # This is here mostly for debugging. Not much can be done about an error
        # at this point.
        logger.warn("#{self.class}-#{self.object_id}: client barfed all over us: #{e} -- #{e.message}")
        logger.warn("#{self.class}-#{self.object_id}: #{e.backtrace * "\n"}")
      end
    end
  end

  private
  def logger
    RAILS_DEFAULT_LOGGER
  end

  # Given a client (TCPSocket), sends all log entries the client is missing
  # based on the client's version vector, then closes the socket. Any multitude
  # of errors may be thrown, all of them fatal.
  def handle_client(client)
    client_vector = get_vector(client)
    logger.info("#{self.class}-#{self.object_id}: got client's version vector: #{client_vector.inspect}")
    if client_vector
      logger.info("#{self.class}-#{self.object_id}: ACKing version vector...")
      send_ack(client, :FLG => :success)
      logger.info("#{self.class}-#{self.object_id}: sending missing logs...")
      send_missing_logs(client, client_vector)
    else
      logger.warn("#{self.class}-#{self.object_id}: Failed to get version vector from client")
      send_ack(client, :FLG => :error, :MSG => "Invalid version vector.")
    end
  ensure
    # This ensures the connection is closed even if an exception is raised.
    client.close
  end

  # Waits for the client to send the vector across the wire, does some basic
  # validation. Returns a Ruby hash object (parsed from the JSON) if the vector
  # was valid, nil otherwise.
  def get_vector(client)
    logger.info("#{self.class}-#{self.object_id}: Waiting for client's vector...")
    # Wait at most 5 seconds to receive a client's vector before
    client_vector = nil
    Timeout.timeout(10) do
      # Read the byte-length prefix off the front of the message, then try
      # to read that many bytes.
      byte_length = client.read_length_field
      # Read the vector data off the socket
      client_vector = client.read(byte_length)
    end
    # Now try to parse JSON
    logger.info("#{self.class}-#{self.object_id}: Received client vector: #{client_vector}")
    return Yajl::Parser.parse(client_vector)
  end

  # Based on the client's vector, determines what log entries are missing on
  # the client's side and delivers them to the given client.
  def send_missing_logs(client, client_vector)
    missing_logs = get_missing_logs(client_vector)
    # For each missing log, convert to json and send, then wait for ack.
    missing_logs.each do |log|
      log_json = log.to_json.prefix_with_length!
      logger.info("#{self.class}-#{self.object_id}: about to send #{log_json}")
      client.write(log_json)
      logger.info("#{self.class}-#{self.object_id}: waiting for ACK of #{log_json}")
      wait_for_ack(client, 20, logger)
    end
  end

  # Given the client's version vector, returns an array of all of the Log entries
  # which the client is ostensibly missing, sorted globally by timestamp.
  def get_missing_logs(client_vector)
    missing_logs = []
    local_vector = Log.get_version_vector
    local_vector.each do |uuid, timestamp|
      # If the client has no info for this UUID, or if it is out of date...
      if client_vector[uuid].nil? or client_vector[uuid] < timestamp
        client_ts = client_vector[uuid] || 0
        missing_logs += Log.find(:all,
                                 :conditions => ["UID = ? AND TS > ?", uuid, client_ts],
                                 :order => "TS ASC")
      end
    end
    # Sort all missing logs by timestamp, breaking ties by OUID
    missing_logs.sort! do |a, b|
      if a.ts == b.ts
        a.ouid <=> b.ouid
      else
        a.ts <=> b.ts
      end
    end
  end
end

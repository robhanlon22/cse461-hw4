require 'socket'

AntiEntropyServer = Struct.new(:tcp_port) do
  include Elmo

  def logger
    Delayed::Worker.logger
  end

  def perform
    server = nil
    begin
      Timeout.timeout(10) do
        logger.info("Starting TCP server on port #{tcp_port}")
        server = TCPServer.new(tcp_port)
        client = server.accept
        logger.info("Accepted client")
        begin
          handle_client(client)
        rescue Exception => e
          # This is here mostly for debugging. Not much can be done about an error
          # at this point.
          STDERR.puts "Client barfed all over us: #{e} -- #{e.message}"
          STDERR.puts *e.backtrace
        end
      end
    ensure
      server.close rescue Exception
      sleep 5
      Delayed::Job.enqueue(AntiEntropyServer.new(tcp_port))
    end
  end

  # Given a client (TCPSocket), sends all log entries the client is missing
  # based on the client's version vector, then closes the socket. Any multitude
  # of errors may be thrown, all of them fatal.
  def handle_client(client)
    client_vector = get_vector(client)
    logger.info("Got client's version vector: #{client_vector}")
    if client_vector
      logger.info("ACK")
      send_ack(client, :success)
      logger.info("Sending missing logs...")
      send_missing_logs(client, client_vector)
    else
      send_ack(client, :error, :message => "Invalid log vector.")
    end
  ensure
    # This ensures the connection is closed even if an exception is raised.
    client.close
  end

  # Waits for the client to send the vector across the wire, does some basic
  # validation. Returns a Ruby hash object (parsed from the JSON) if the vector
  # was valid, nil otherwise.
  def get_vector(client)
    # Wait at most 5 seconds to receive a client's vector before
    client_vector = nil
    Timeout.timeout(5) do
      # Read the byte-length prefix off the front of the message, then try
      # to read that many bytes.
      byte_length = ""
      while (next_char = client.getc.chr) != ":"
        byte_length << next_char
      end
      # Convert from number string to integer
      byte_length = byte_length.to_i
      # Read the vector data off the socket
      client_vector = client.read(byte_length)
    end
    # Now try to parse JSON
    return Yajl::Parser.parse(client_vector)
  rescue Timeout::Error, Yajl::ParseError
    # Either the client timed out, or their vector was poorly formatted
    return nil
  end

  # Based on the client's vector, determines what log entries are missing on
  # the client's side and delivers them to the given client.
  def send_missing_logs(client, client_vector)
    missing_logs = get_missing_logs(client_vector)
    # For each missing log, convert to json and send, then wait for ack.
    missing_logs.each do |log|
      log_json = log.to_json.prefix_with_length!
      client.write(log_json)
      wait_for_ack(client)
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
                                 :conditions => ["UUID = ? AND TS > ?", uuid, client_ts],
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

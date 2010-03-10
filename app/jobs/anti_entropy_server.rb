require 'socket'

AntiEntropyServerJob = Struct.new(:tcp_port) do
  include Elmo

  def perform
    server = TCPServer.new(@tcp_port)
    loop do
      client = server.accept
      handle_client(client)
    end
  end

  def handle_client(client)
    client_vector = get_vector(client)
    begin
      if client_vector
        send_ack(client, :success)
        send_missing_logs(client, client_vector)
      else
        send_ack(client, :error, :message => "Invalid log vector.")
      end
    rescue => e
      # If we've gotten here, chances are we've either got a bug (in which case
      # we're going to kill the app and find it) or the connection died. Print
      # info and drop this client.
      STDERR.puts "Experienced error while trying to handle client: #{e}"
      STDERR.puts *e.backtrace[0...15]
    end
    client.close
  end

  # Waits for the client to send the vector across the wire, does some basic
  # validation. Returns a Ruby hash object (parsed from the JSON) if the vector
  # was valid, nil otherwise.
  def get_vector(client)
    # Wait at most 5 seconds to receive a client's vector before
    client_vector = nil
    begin
      Timeout::timeout(5) do
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
      client_vector = Yajl::Parser.parse(client_vector)
    rescue Timeout::Error, Yajl::ParseError
      # Either the client timed out, or their vector was poorly formatted
      client_vector = nil
    end
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
        logs_for_uuid += Log.find(:all,
                                  :conditions => ["UUID = ? AND TS > ?", uuid, client_ts],
                                  :order => "TS ASC")
        missing_logs = merge_sorted_log_lists(missing_logs, logs_for_uuid)
      end
    end

    return missing_logs
  end

  # Given two lists of Log entries, each sorted by increasing timestamp, returns
  # the sorted combination of the two lists (neither list is modified).
  def merge_sorted_log_lists(first, second)
    if first.empty?
      return second
    elsif second.empty?
      return first
    else
      # creates a new list of size (first+second) filled with nil
      merged_list = Array.new(first.size + second.size, nil)
      first_index = 0
      second_index = 0

      # For each space in the final list, chooses the lowest-timestamp'd
      # Log that has yet to be chosen from either list.
      merged_list.map! do |log|
        if first_index < first.length and second_index < second.length
          if first[first_index].ts < second[second_index].ts
            log_to_use = first[first_index]
            first_index += 1
          else
            log_to_use = second[second_index]
            second_index += 1
          end
        elsif first_index >= first.length
          log_to_use = second[second_index]
          second_index += 1
        else
          log_to_use = first[first_index]
          first_index += 1
        end
        log_to_use
      end
    end
  end
end

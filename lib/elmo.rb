module Elmo
  
  # Send an ACK to the given socket. Possible options:
  #
  # :FLG => :SUCCESS|:ERROR (success/error value is case insensitive)
  # :MSG => <message-text>
  #
  # Throws ArgumentError if invalid options are given.
  def send_ack(socket, opts={})
    allowed_opts = [ :FLG, :MSG ]
    
    opts.each_key |option|
      unless allowed_opts.contains?(option)
        raise ArgumentError.new("Illegal ACK option given: '#{option}'")
      end
    end
    ack = { :OP => "ACK" }.merge(opts)
    ack[:FLG] = ack[:FLG].to_s.upcase if ack[:FLG]
    
    ack_json = Yajl::Encoder.encode(ack).prefix_with_length!
    socket.write(ack_json)
  end
  
  # Given a socket, waits for an ACK to arrive on that socket. An optional timeout
  # period (in seconds) can be given, but otherwise it will default to five. If
  # the connection times out, a Timeout::Error will be raised. If the ACK received
  # is invalid, an ArgumentError will be raised. If the ACK indicates an error,
  # an AckError will be raised, and the exception's message will match the ACK's
  # message.
  def wait_for_ack(socket, timeout=5)
    Timeout::timeout(timeout) do
      length = socket.read_length_field
      ack = Yajl::Parser.parse(socket.read(length))
    end
    
    if ack["FLG"] == "ERROR"
      message = ack["MSG"] || "ACK ERROR contained no message."
      raise AckError.new(message)
    end
  rescue Yajl::ParseError => e
    raise ArgumentError.new("Parse error:\n#{e.message}")
  end
  
  class AckError < StandardError
  end
end
require 'socket'

class BroadcastDelegator
  def perform
    BasicSocket.do_not_reverse_lookup = true
    sock = UDPSocket.bind('0.0.0.0', 30000)
    loop do
      data, addr = sock.recvfrom(1024)
      if valid?(data)
        data = data.split
        Delayed::Job.new(AntiEntropyClient.new(addr[2], data.last.to_i))
      end
      sleep 5
    end
  rescue
    Delayed::Job.new(BroadcastDelegator)
  end

  private
  def valid?(data)
    data =~ /^flickr \d{1,5}$/
  end
end

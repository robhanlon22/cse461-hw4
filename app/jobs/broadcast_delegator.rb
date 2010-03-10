$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))

require 'socket'
require 'anti_entropy_client'

class BroadcastDelegator
  def perform
    BasicSocket.do_not_reverse_lookup = true
    logger.info("Listening for broadcasts...")
    sock = UDPSocket.bind('0.0.0.0', 30000)
    logger.info("Waiting for data...")
    data, addr = sock.recvfrom(1024)
    logger.info("Received data.")
    logger.info("data = #{data}, from #{addr[2]}")
    if valid?(data)
      logger.info("data was valid, starting anti-entropy client...")
      data = data.split
      Delayed::Job.new(AntiEntropyClient.new(addr[2], data.last.to_i))
    end
  rescue Exception => e
    logger.warn(e)
  ensure
    sock.close
    logger.info("Sleeping for 5 seconds...")
    sleep 5
    Delayed::Job.enqueue(new(logger))
  end

  private
  def valid?(data)
    data =~ /^flickr \d{1,5}$/
  end
end

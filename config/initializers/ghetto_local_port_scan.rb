require 'socket'
require 'timeout'

def port_open?(port)
  Timeout::timeout(1) do
    s = TCPServer.new(port)
    s.close
    return true
  end
rescue Exception
  return false
end

unless defined? PORT
  ports = [*1024...65536].shuffle
  until ports.empty?
    port = ports.pop
    if port_open?(port)
      break PORT = port
    end
  end
end

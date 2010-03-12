module TsMs
  # This is a VERY important method because the protocol demands MILLISECONDS!
  # Ruby's Time object's to_i method returns SECONDS. We need to convert. This
  # method returns an INTEGER (not DateTime) value of the epoch time in MS.
  def ts_ms
    ts_millis = ts.to_i * 1000
    ts_millis += ts.usec / 1000 # Add millisecond accuracy (microseconds / 1000)
  end
end

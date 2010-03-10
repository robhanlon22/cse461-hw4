module StringExtensions
  def prefix_with_length!
    replace("#{length}:#{self}")
  end

  def strip_length_prefix!
    self =~ /^\d+:/ and replace($')
  end
end

String.__send__(:include, StringExtensions)

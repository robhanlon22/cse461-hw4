module IoExtensions
  def read_length_field
    length = ''
    until (c = getc) == ?: or c.nil?
      length << c
    end
    length.to_i
  end
end

IO.__send__(:include, IoExtensions)
StringIO.__send__(:include, IoExtensions)

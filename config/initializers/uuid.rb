def assign_uuid
  uuid_file_name = File.join("#{RAILS_ROOT}", ".#{RAILS_ENV}-uuid")

  if File.exists?(uuid_file_name)
    uuid = File.read(uuid_file_name).chomp
    return uuid if uuid =~ Log::UUID_FORMAT
  end

  uuid = UUID.new.generate
  uuid_file = File.new(uuid_file_name, 'w')
  uuid_file.write(uuid)
  uuid_file.close

  uuid
end

APP_UUID = assign_uuid

class Log < ActiveRecord::Base
  include ActiveRecord::Serialization

  DEFAULT_JSON_FIELDS = [:OP, :TYPE, :UID, :TS, :OUID]
  VECTOR_SELECTOR = {:select => 'OUID, TS, MAX(TS)', :group => 'OUID'}

  column_names.each do |attr|
    alias_attribute attr.downcase, attr unless attr == 'id'
  end

  validates_inclusion_of    :OP,
                            :in => %w[WRITE DELETE]
  validates_presence_of     :TYPE,
                            :in => %w[COMMENT PHOTO]
  validates_format_of       :UID,
                            :OUID,
                            :with => UUID_FORMAT
  validates_format_of       :PUID,
                            :with => UUID_FORMAT,
                            :allow_nil => true

  # Ensures that no two log entries can have the same timestamp and origin UUID
  validates_uniqueness_of   :TS,
                            :scope => :OUID

  alias_method :to_json_old, :to_json

  # Based on all of the known timestamps in the log, as well as the current
  # local time, returns the timestamp value (a Time object, not an integer) that
  # should be used for a new action.
  def self.next_timestamp
    max_ts = Log.maximum('TS')
    ts_to_use = nil
    if max_ts.nil?
      ts_to_use = Time.now
    else
      ts_to_use = [max_ts, Time.now].max
    end
    
    # Time objects + operator expects seconds, not milliseconds
    ts_to_use + 0.001
  end

  # Given an array of log entry hashes (parsed from JSON), convert them to Log
  # records and save them in our database.
  def self.add_logs(log_hashes)
    # Make sure that logs are sorted, just in case...
    log_hashes.sort! do |hash1, hash2|
      if hash1['TS'] == hash2['TS']
        hash1['OUID'] <=> hash2['OUID']
      else
        # These timestamps will be strings. Convert.
        hash1['TS'].to_i <=> hash2['TS'].to_i
      end
    end
    
    Log.transaction do
      log_hashes.each do |log_hash|
        log = Log.new(log_hash)
        
        # This is a little complicated because of Ruby's seconds-based Time obj.
        # This timestamp is in millis, so we need to convert.
        log.ts = datetime_from_millis(log_hash['TS'])

        # Ensure that we never admit duplicate logs!
        if log.valid?
          log.save!
        end
      end
    end
  end

  def self.replay
    ActiveRecord::Base.transaction do
      Photo.destroy_all
      Comment.destroy_all

      Log.all(:order => 'TS ASC').each do |log|
        if log.write?
          e = nil
          if log.photo?
            data = Base64.decode64(log.data)
            sio = StringIO.new(data)
            sio.original_filename = log.uid
            e = Photo.new(:image => sio)
          else # comment
            e = Comment.new(:puid => log.puid,
                            :text => log.data)
          end
          e.ts = log.ts
          e.uid = log.uid
          e.ouid = log.ouid
          e.save
        else
          (log.photo? ? Photo : Comment).find_by_uid(log.uid).destroy
        end
      end
    end
  end

  def self.get_version_vector
    all(VECTOR_SELECTOR).inject({}) do |memo, entry|
      memo[entry.ouid] = entry.ts_ms.to_s
      memo
    end
  end

  def self.for_comment(comment)
    Log.new(:OP   => "WRITE",
            :TYPE => "COMMENT",
            :TS   => comment.ts,
            :UID  => comment.uid,
            :PUID => comment.puid,
            :OUID => comment.ouid,
            :DATA => comment.text,
            :SIZE => comment.text.size)
  end

  # Auto-generates the next available timestamp
  def self.for_comment_delete(comment, instance_uuid=APP_UUID)
    Log.new(:OP   => "DELETE",
            :TYPE => "COMMENT",
            :UID  => comment.uid,
            :TS   => next_timestamp,
            :OUID => instance_uuid)
  end

  def self.for_photo(photo)
    # Read the file's bits from disk...
    data = Base64.encode64(File.read(photo.image.path))
    Log.new(:OP   => "WRITE",
            :TYPE => "PHOTO",
            :TS   => photo.ts,
            :UID  => photo.uid,
            :OUID => photo.ouid,
            :DATA => data,
            :SIZE => data.size)
  end

  # Auto-generates the next available timestamp
  def self.for_photo_delete(photo, instance_uuid=APP_UUID)
    Log.new(:OP   => "DELETE",
            :TYPE => "PHOTO",
            :UID  => photo.uid,
            :TS   => next_timestamp,
            :OUID => instance_uuid)
  end
  
  def validate
    # Two things should go here, but we can't put them here until we're
    # sure of how transactions commit things to the DB:
    #
    # - No comment should save if it refers to a photo that doesn't exist
    # - No delete should work if an object with that UUID does not exist
  end
  
  # Like in Perl, this is a comparison operator. This orders first by timestamp,
  # breaking ties on OUID.
  def <=>(other)
    if self.ts == other.ts
      self.ouid <=> other.ouid
    else
      self.ts <=> other.ts
    end
  end

  # This is a VERY important method because the protocol demands MILLISECONDS!
  # Ruby's Time object's to_i method returns SECONDS. We need to convert. This
  # method returns an INTEGER (not DateTime) value of the epoch time in MS.
  def ts_ms
    ts_millis = ts.to_i * 1000
    ts_millis += ts.usec / 1000 # Add millisecond accuracy (microseconds / 1000)
  end

  def to_json
    s = nil
    if write?
      if comment?
        s = Serializer.new(self, :only => DEFAULT_JSON_FIELDS + [:PUID, :SIZE, :DATA])
      else # photo
        s = Serializer.new(self, :only => DEFAULT_JSON_FIELDS + [:SIZE, :DATA])
      end
    else # delete
      s = Serializer.new(self, :only => DEFAULT_JSON_FIELDS)
    end
    returning(hash = s.serializable_record) { hash['TS'] = self.ts_ms.to_s }.to_json
  end

  def write?
    op == 'WRITE'
  end

  def delete?
    op == 'DELETE'
  end

  def comment?
    type == 'COMMENT'
  end

  def photo?
    type == 'PHOTO'
  end
  
  private
  
  # A Ruby Time object can either be specified by either seconds or microseconds.
  # We'll need to take a millisecond timestamp and convert to microseconds.
  # Returns a Time object (which ActiveRecord converts to DateTime for us) with
  # the proper value.
  def datetime_from_millis(millis_timestamp)
    millis_timestamp = millis_timestamp.to_i # just in case it's a string
    seconds = millis_timestamp / 1000
    remainder_microsecs = (millis_timestamp % 1000) * 1000
    
    # This method takes seconds as a first parameter, and REMAINDER microseconds
    # as a second parameter.
    Time.at(seconds, remainder_microsecs)
  end
end

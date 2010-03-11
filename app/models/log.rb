class Log < ActiveRecord::Base
  DEFAULT_JSON_FIELDS = [:OP, :TYPE, :UID, :TS, :OUID]
  VECTOR_SELECTOR = {:select => 'UID, TS, MAX(TS)', :group => 'UID'}

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

  alias_method :to_json_old, :to_json
  
  # Based on all of the known timestamps in the log, as well as the current
  # local time, returns the timestamp value (a Time object, not an integer) that
  # should be used for a new action.
  def self.next_timestamp
    max_ts = Log.maximum('TS')
    Time.at(([max_ts.to_i, Time.now.to_i].max) + 1)
  end

  def self.add_logs(log_hashes)
    Log.transaction do
      log_hashes.each do |log_hash|
        log = new(log_hash)
        log.ts = Time.at(log.ts.to_i)
        log.save
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
    all(VECTOR_SELECTOR).inject({}) { |memo, entry|
      memo[entry.uid] = entry.ts.to_i.to_s
      memo
    }
  end
  
  def self.for_comment(comment)
    Log.new(:OP   => "WRITE",
            :TYPE => "COMMENT",
            :TS   => comment.ts,
            :UID  => comment.uid,
            :PUID => comment.puid,
            :OUID => comment.ouid,
            :data => comment.text)
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
    data = nil
    File.open(photo.image.path, "rb") do |file|
      data = Base64::encode64(file.read)
    end
    Log.new(:OP   => "WRITE",
            :TYPE => "PHOTO",
            :TS   => photo.ts,
            :UID  => photo.uid,
            :OUID => photo.ouid,
            :DATA => data)
  end
  
  # Auto-generates the next available timestamp
  def self.for_photo_delete(photo, instance_uuid=APP_UUID)
    Log.new(:OP   => "DELETE",
            :TYPE => "PHOTO",
            :UID  => photo.uid,
            :TS   => next_timestamp,
            :OUID => instance_uuid)
  end

  def to_json
    if write?
      if comment?
        to_json_old(:only => DEFAULT_JSON_FIELDS + [:PUID, :SIZE, :DATA])
      else # photo
        to_json_old(:only => DEFAULT_JSON_FIELDS + [:SIZE, :DATA])
      end
    else # delete
      to_json_old(:only => DEFAULT_JSON_FIELDS)
    end
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
end

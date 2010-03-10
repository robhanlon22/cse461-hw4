class Log < ActiveRecord::Base
  DEFAULT_JSON_FIELDS = [:OP, :TYPE, :UID, :TS, :OUID]
  UUID_FORMAT = /\w{8}-(?:\w{4}-){3}\w{12}/
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

  def self.get_version_vector
    all(VECTOR_SELECTOR).inject({}) { |memo, entry|
      memo[entry.uid] = entry.ts.to_i.to_s
      memo
    }.to_json
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

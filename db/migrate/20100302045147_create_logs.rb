class CreateLogs < ActiveRecord::Migration
  def self.up
    create_table :logs do |t|
      t.string   :OP,   :null => false
      t.string   :TYPE, :null => false
      t.string   :UID,  :null => false
      t.datetime :TS,   :null => false
      t.string   :OUID, :null => false
      t.string   :PUID
      t.string   :SIZE
      t.string   :DATA
    end
  end

  def self.down
    drop_table :logs
  end
end

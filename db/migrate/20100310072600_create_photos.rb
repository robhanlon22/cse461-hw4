class CreatePhotos < ActiveRecord::Migration
  def self.up
    create_table :photos do |t|
      t.string :uid
      t.string :ouid
      t.datetime :ts
    end
  end

  def self.down
    drop_table :photos
  end
end

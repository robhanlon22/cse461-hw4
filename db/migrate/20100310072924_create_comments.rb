class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments do |t|
      t.string :text
      t.datetime :ts
      t.string :ouid
      t.string :uid
      t.string :puid
    end
  end

  def self.down
    drop_table :comments
  end
end

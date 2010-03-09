require 'spec_helper'

describe Log do
  before(:each) do
    @valid_attributes = {
      :op => "value for op",
      :type => "value for type",
      :ts => Time.now,
      :uid => "value for uid",
      :puid => "value for puid",
      :ouid => "value for ouid",
      :size => 1,
      :data => "value for data"
    }
  end

  it "should create a new instance given valid attributes" do
    Log.create!(@valid_attributes)
  end
end

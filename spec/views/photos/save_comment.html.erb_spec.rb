require 'spec_helper'

describe "/photos/save_comment" do
  before(:each) do
    render 'photos/save_comment'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/photos/save_comment])
  end
end

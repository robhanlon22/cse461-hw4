require 'spec_helper'

describe PhotosController do

  #Delete these examples and add some real ones
  it "should use PhotosController" do
    controller.should be_an_instance_of(PhotosController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'list'" do
    it "should be successful" do
      get 'list'
      response.should be_success
    end
  end

  describe "GET 'view'" do
    it "should be successful" do
      get 'view'
      response.should be_success
    end
  end

  describe "GET 'new'" do
    it "should be successful" do
      get 'new'
      response.should be_success
    end
  end

  describe "GET 'create'" do
    it "should be successful" do
      get 'create'
      response.should be_success
    end
  end

  describe "GET 'destroy'" do
    it "should be successful" do
      get 'destroy'
      response.should be_success
    end
  end

  describe "GET 'comment'" do
    it "should be successful" do
      get 'comment'
      response.should be_success
    end
  end

  describe "GET 'save_comment'" do
    it "should be successful" do
      get 'save_comment'
      response.should be_success
    end
  end

  describe "GET 'delete_comment'" do
    it "should be successful" do
      get 'delete_comment'
      response.should be_success
    end
  end
end

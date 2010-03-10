class PhotosController < ApplicationController
  before_filter :init_latest_photos, :only => [ :index,
                                                :list,
                                                :view,
                                                :new ]
  
  def index
    @page_title = "Welcome"
    
    # Figure out what active (i.e., "photo-posting") UUIDs there are
    photos = Photo.find_by_sql("SELECT DISTINCT OUID FROM photos ORDER BY OUID ASC")
    @instances = photos.map { |photo| photo.ouid }
    logger.info(@instances.inspect)
  end

  def list
    @page_title = "Listing photos"
    
    # If the user is trying to UUID-restrict the photos, make sure the UUID 
    # corresponds to a valid instance.
    find_options = { :order => "ts ASC"}
    if params[:uuid]
      logs = Log.find(:all, :conditions => ["OUID = ?", params[:uuid]])
      find_options.merge!(:conditions => ["ouid = ?", params[:uuid]]) unless logs.empty?
    end
    
    @photos = Photo.find(:all, find_options)
  end

  def view
    if params[:uuid].nil?
      logger.error("Attempt to view photo without specifying UUID.")
      redirect_to( :action => :index ) and return
    end
    
    @page_title = "Viewing a photo"
    
    @photo = Photo.find_by_uid(params[:uuid])    
    if @photo
      @comments = Comment.find_all_by_puid(params[:uuid])
    else
      logger.error("Attempt to view photo with bogus (or unknown) UUID.")
      redirect_to( :action => :index ) and return
    end
  end

  def new
    @page_title = "Add a new photo"
    
    @photo = Photo.new
  end

  def create
    if params[:photo].nil?
      logger.error("Attempt to add a photo without sending any data.")
      redirect_to( :action => :index ) and return
    end
        
    photo_ts = Log.next_timestamp
    photo_uuid = UUID.new.generate
    photo = Photo.new(params[:photo].merge(:uid => photo_uuid,
                                           :ts => photo_ts,
                                           :ouid => APP_UUID))
    begin
      Log.transaction do
        photo.save!
        log_entry = Log.for_photo(photo)
        log_entry.save!
      end
      
      flash[:notice] = "Photo uploaded successfully!"
      redirect_to( :action => :view, :uuid => photo_uuid ) and return
    rescue => e
      logger.error("Failed to upload a new photo: #{e} -- #{e.message}")
      flash[:error] = "Unable to upload your photo."
      redirect_to( :back ) and return
    end
  end

  def destroy
    @page_title = "Not implemented yet..."
  end

  def save_comment
    if params[:comment].nil?
      logger.error("Attempt to post a comment without sending form data.")
      redirect_to( :action => :index ) and return
    elsif params[:comment][:puid].nil?
      logger.error("Attempt to post a comment without associated photo puid.")
      redirect_to( :action => :index ) and return
    end
    
    photo = Photo.find_by_uid(params[:comment][:puid])
    if photo
      comment_ts = Log.next_timestamp
      comment_uuid = UUID.new.generate
      begin
        # Atomically add both a comment object AND add a corresponding Log entry
        Log.transaction do
          # Comment first so that if it doesn't validate, we short-circuit early
          comment = Comment.new(params[:comment].merge(:ts => comment_ts,
                                                       :uid => comment_uuid,
                                                       :ouid => APP_UUID))
          comment.save!
          log_entry = Log.for_comment(comment)
          log_entry.save!
        end
        
        flash[:notice] = "Comment saved successfully!"
      rescue => e
        logger.error("Failed to create comment: #{e} -- #{e.message}")
        flash[:error] = "Could not save comment."
      end  
      redirect_to( :back ) and return
    else
      logger.error("Attempt to post a comment with bogus (or unknown) UUID.")
      redirect_to( :action => :index ) and return
    end
  end

  def delete_comment
    if params[:uuid].nil?
      logger.error("Attempted deletion of a comment without specifying uuid.")
      redirect_to( :action => :index ) and return
    end
    
    # TODO: DECIDE ON A DELETION POLICY! CAN X DELETE Y's STUFF?
    comment = Comment.find_by_uid(params[:uuid])
    if comment
      log_entry = Log.for_comment_delete(comment)
      begin
        Log.transaction do
          log_entry.save!
          comment.destroy
        end
        flash[:notice] = "Comment deleted successfully!"
      rescue => e
        logger.error("Failed to delete comment: #{e} -- #{e.message}")
        flash[:error] = "Could not delete comment..."
      end
      redirect_to( :back ) and return
    else
      logger.error("Attempted deletion of comment with bogus (or unknown) UUID.")
      redirect_to( :action => :index ) and return
    end
  end
  
  private
  
  # Initializes a @latest_photos variable containing up to 5 of the most
  # recently added photos.
  def init_latest_photos
    @latest_photos = Photo.find(:all, :order => "ts DESC", :limit => 5)
  end
end

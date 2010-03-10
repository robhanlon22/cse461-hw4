module PhotosHelper
  def comments_for_photo(photo)
    Comment.find(:all, :conditions => ["puid = ?", photo.uid], :order => "ts ASC")
  end
end

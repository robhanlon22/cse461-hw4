class Photo < ActiveRecord::Base
  include TsMs

  has_attached_file :image
end

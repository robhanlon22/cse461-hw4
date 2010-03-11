# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  # Returns an image tag for an icon with the specified name and any additional options
  def icon(name, opts={})
    options = { :size => 16, :alt => '', :class => 'icon', :shadow => true }
    options.merge!(opts)
    name = name.to_s
    size = options[:size].to_s
    dims = size + 'x' + size
    image_tag '/images/icons/' + dims + (options[:shadow] ? '/shadow/' : '/plain/') + name + '.png',
              :alt => options[:alt],
              :class => options[:class],
              :width => size,
              :height => size,
              :id => options[:id],
              :onmouseover => options[:onmouseover],
              :onmouseout => options[:onmouseout],
              :onclick => options[:onclick]
  end
end

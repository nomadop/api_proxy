module Panoramio
  URL = 'http://www.panoramio.com/map/get_panoramas.php'
  DEFAULT_OPTIONS = {
    :set => :public,  # Cant be :public, :full, or a USER ID number
    :size => :medium, # Cant be :original, :medium (default value), :small, :thumbnail, :square, :mini_square
    :from => 0,
    :to => 5,
    :mapfilter => true
  }

  class Photo < OpenStruct
    def as_json *args
      super['table']
    end
  end
  
  def self.get_panoramas(options = {})
    panoramio_options = DEFAULT_OPTIONS
    panoramio_options.merge!(options)
    response = Faraday.new.get(URL, panoramio_options)
    if response.status == 200
      parse_data = JSON.parse(response.body)
    else
      raise "Panoramio API error: #{response.code}. Response #{response.to_str}"
    end
  end

  def self.get_panoramas_from_point(lat, lng, radius = 10, options = {})
    bound = Geokit::Bounds.from_point_and_radius([lat, lng], radius)
    points = bound.to_a.flatten
    options.merge!({
      :miny => points[0],
      :minx => points[1],
      :maxy => points[2],
      :maxx => points[3] 
    })
    res = self.get_panoramas(options)
    res['photos'].map{|p| Photo.new(p)}
  end
end
class ApiController < ApplicationController
  protect_from_forgery except: :proxy
  require 'pp'

  def panoramio
    lat, lng, callback = params.delete(:lat), params.delete(:lng), params.delete(:callback)
    data = Panoramio.get_panoramas_from_point(lat, lng, 10, params)
    if callback
      render text: "#{callback}(#{data.to_json})"
    else
      render json: data
    end
  end

  def translate
  	provider = params[:provider] || params[:p]
  	case provider
  	when /google.*api/
  		render json: GoogleApis::Wraper.translate(translate_params)
  	when /google.*web/
  		render json: GoogleApis::Crawler.translate(translate_params)
  	else
  		render json: "unknown provider `#{params[:provider]}'"
  	end
  end

  def stations_in
  	render json: GoogleMaps::Place.stations_in(params[:q])
  end

  def place
  	render json: GoogleMaps::Wraper.place(params[:method], place_params)
  end

  def geocode
  	query = params[:q] || params[:query]
  	api = params[:api] || 'google'
    callback = params[:callback]
  	bias = if params[:bias]
  		params[:bias]
 		elsif params[:bounds]
 			Geokit::Geocoders::GoogleGeocoder.geocode(params[:bounds]).suggested_bounds
 		else
 			nil
 		end
 			
  	loc = GeocodeApi.geocode(query, api.to_sym, bias: bias)
  	data = loc.as_json.merge({suggested_bounds: loc.suggested_bounds})
    if callback
      render text: "#{callback}(#{data.to_json})"
    else
      render json: data
    end
  end

  def proxy
  	url = CGI.unescape(params[:url]).gsub(/&amp;/, '&')
  	host = url.match(/https?:\/\/(.*?)\//) || url.match(/https?:\/\/(.*?)$/)
  	host = host[1]
  	uri = '/' + url.split('/')[3..-1].join('/')
  	res = nil
  	Net::HTTP.start(host) do |http|
  		res = http.get(uri)
  	end
  	if res.header['content-type'].split(';').first == 'text/html'
  		doc = Nokogiri::HTML(res.body)
  		regexp = /[\'\"](https?:\\?\/\\?\/.*?)[\'\"]/ 
  		html = doc.to_s.gsub(regexp){|u| "/api/proxy?url=#{CGI.escape(u[1...-1])}"}
  		send_data html, disposition: 'inline', type: res.header['content-type']
  	else
  		send_data res.body, disposition: 'inline', type: res.header['content-type']
  	end
  end

	def direction
		@response = {}
		begin
			origin = params[:o] || params[:oName] || params[:origin]
			destination = params[:d] || params[:dName] || params[:destination]
			provider = params[:p] || params[:provider]
			if origin && destination
				case provider
				when /rome2rio/i
					direction = GoogleMaps::Direction.query_from_rome2rio(origin, destination, direction_params)
					data = direction.as_json.merge({'provider' => 'Rome2rio'})
				when /mixed/i
					direction = GoogleMaps::Direction.new(origin, destination, direction_params)
					direction.query
					gdata = direction.as_json
					gdata['routes'].each { |r| r.merge!({'provider' => 'GoogleMaps'}) }
					direction = GoogleMaps::Direction.query_from_rome2rio(origin, destination, direction_params)
					rdata = direction.as_json
					rdata['routes'].each { |r| r.merge!({'provider' => 'Rome2rio'}) }
					gdata['routes'] += rdata['routes']
					gdata['routes'].sort! do |a, b|
						if travel_level(a) == travel_level(b)
							a['duration'] <=> b['duration']
						else
							travel_level(a) <=> travel_level(b)
						end
					end
					data = gdata.merge({'provider' => 'Mixed'})
				else # when /google/i
					direction = GoogleMaps::Direction.new(origin, destination, direction_params)
					direction.query
					data = direction.as_json.merge({'provider' => 'GoogleMaps'})
				end
				@response = { status: 200, data: data }
			else
				@response = { status: 204, data: 'INVALID_REQUEST: wrong number of parameters' }
			end
		rescue Exception => e
			@response = { status: 500, data: 'Server error', error: e.inspect, backtrace: e.backtrace }
		end

		respond_to do |format|
      format.html
      format.json { render json: JSON.generate(@response) }
    end
	end

	private
		def travel_level route
			mode = route['steps'].map{|s| s['travel_mode']}.uniq.join
			case mode
			when /TRANSIT/, /train/, /bus/, /ferry/
				1
			when /DRIVING/, /car/
				2
			when /WALKING/, /walk/
				3
			end
		end

		def translate_params
			params.permit(:callback, :format, :prettyprint, :q, :source, :sl, :target, :tl)
		end

		def geocode_params
			params.permit(:bias)
		end

		def place_params
			params.permit(:keyword, :minprice, :maxprice, :language, :location, :name, :opennow, :query, :radius, :rankby, :sensor, :types, :pagetoken, :zagatselected)
		end

		def direction_params
      params.permit(:sensor, :mode, :waypoints, :alternatives, :avoid, :units, :region, :departure_time, :arrival_time, :preload)
    end
end
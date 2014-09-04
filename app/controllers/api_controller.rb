class ApiController < ApplicationController
  # protect_from_forgery :only  => []
  require 'pp'

  def stations_in
  	render json: GoogleMaps::Place.stations_in(params[:q])
  end

  def place
  	render json: GoogleMaps::Wraper.place(params[:method], place_params)
  end

  def geocode
  	query = params[:q] || params[:query]
  	api = params[:api] || 'google'
  	bias = if params[:bias]
  		params[:bias]
 		elsif params[:bounds]
 			Geokit::Geocoders::GoogleGeocoder.geocode(params[:bounds]).suggested_bounds
 		else
 			nil
 		end
 			
  	loc = GeocodeApi.geocode(query, api.to_sym, bias: bias)
  	render json: loc
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
				when /google/i
					direction = GoogleMaps::Direction.new(origin, destination, direction_params)
					direction.query
					data = direction.as_json.merge({'provider' => 'GoogleMaps'})
				else
					direction = GoogleMaps::Direction.new(origin, destination, direction_params)
					direction.query
					gdata = direction.as_json
					gdata['routes'].each { |r| r.merge!({'provider' => 'GoogleMaps'}) }
					direction = GoogleMaps::Direction.query_from_rome2rio(origin, destination, direction_params)
					rdata = direction.as_json
					rdata['routes'].each { |r| r.merge!({'provider' => 'Rome2rio'}) }
					gdata['routes'] += rdata['routes']
					gdata['routes'].sort_by { |r| r['duration'] }
					data = gdata
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
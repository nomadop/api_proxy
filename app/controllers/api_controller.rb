class ApiController < ApplicationController
  # protect_from_forgery :only  => []
  require 'pp'

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
				when 'rome2rio'
					ll_regexp = /-?\d+.\d+\,-?\d+.\d+/
					rome2rio_params = {key: 'INyVvCSX', flags: '0x0000000F'}
					rome2rio_params.merge!(if origin =~ ll_regexp
											{oPos: origin, dPos: destination}
										else
											{oName: origin, dName: destination}
										end)
					res = Rome2rio::Connection.new.search(rome2rio_params)
					case res
					when Rome2rio::SearchResponse
						direction = GoogleMaps::Direction.parse_rome2rio_data(res, preload: params[:preload])
						data = direction.as_json.merge({'provider' => 'Rome2rio'})
					when Hash
						data = { 'origin' => nil, 'destination' => nil, 'routes' => [], 'response' => res, 'provider' => 'Rome2rio' }	
					else
						raise 'unknown error'
					end
				else # default provider = GoogleMaps
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
		def geocode_params
			params.permit(:bias)
		end

		def direction_params
      params.permit(:sensor, :mode, :waypoints, :alternatives, :avoid, :units, :region, :departure_time, :arrival_time, :preload)
    end
end
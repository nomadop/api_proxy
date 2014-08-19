class ApiController < ApplicationController
  # protect_from_forgery :only  => []
  require 'pp'

  def geocode
  	query = params[:q] || params[:query]
  	api = params[:api] || 'google'
  	loc = GeocodeApi.geocode(query, api.to_sym)
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
					res = Rome2rio::Connection.new.search(oName: params[:o], dName: params[:d], key: 'INyVvCSX', flags: '0x0000000F')
					threads = []
					res.routes.map(&:segments).flatten.each do |seg|
						seg.class.send(:attr_reader, :staticmap_url) unless seg.respond_to?(:staticmap_url)
						if CGI.escape(seg.path).size > 1800
							points = Polylines::Decoder.decode_polyline(seg.path)
							ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(0.0005).points
							ziped_path = Polylines::Encoder.encode_points(ziped_points)
							seg.instance_variable_set :@path, ziped_path
						end
						map_size = case seg.distance
						when 0...1
							'200x200'
						else
							'500x500'
						end
						threads << Thread.new do 
							seg.instance_variable_set(:@staticmap_url, GoogleMaps::Wraper.staticmap([seg.sPos.to_s, seg.tPos.to_s], seg.path, :url, size: map_size)).gsub(/%5B%5D/, '')
							seg.instance_variable_set(:@staticmap, Base64.strict_encode64(GoogleMaps::Wraper.staticmap(seg.staticmap_url))) if params[:preload] == 'true'
						end
					end
					threads.each { |t| t.join }
					data = { 'origin' => params[:o], 'destination' => params[:d], 'routes' => res.routes.select{|r| r.name != 'Walk' && r.name != 'Taxi'}.as_json, 'provider' => 'Rome2rio' }
				else
					direction = GoogleMaps::Direction.new(params[:o], params[:d], direction_params)
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
		def direction_params
      params.permit(:sensor, :mode, :waypoints, :alternatives, :avoid, :units, :region, :departure_time, :arrival_time, :preload)
    end
end
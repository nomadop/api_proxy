# encoding: utf-8

module GoogleMaps
	UrlThresholdBase = 0.0007 / 2000

	class Wraper
		HOST = 'https://maps.googleapis.com'
		KEYS = ['AIzaSyAfy5gDr5-vhv0_ZF_BOQHA4_Fx-6sGJAU',
						'AIzaSyBPLzOXa6a-fLACftN7qLXvxzCyduKGb0M',
						'AIzaSyBgw09mhfPKR1Ded7RIAn7zveSCum2bf20',
						'AIzaSyDvg0BiuEgxxZuf20Bhujw6jYO0BzLYsO0',
						'AIzaSyA7swEwrzDr0SYSqA1lLtuo9RI6CbCIwtA']
		# KEYS = ['AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0']
		PROXY = 'https://127.0.0.1'

		@@current = 0

		def self.key
			@@current += 1
			@@current = 0 if @@current >= KEYS.size
			KEYS[@@current]
		end

		def self.place method, opts = {}
			conn = Conn.init(HOST)
			# conn.options[:proxy] = PROXY
			conn.params = opts.merge({key: 'AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0'})
			response = conn.try(:get, "/maps/api/place/#{method}/json")
			while response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSONObject.new(response.body)
		end

		def self.direction o_name, d_name, opts = {}
			conn = Conn.init(HOST) do |c|
				# c.options[:proxy] = PROXY
				c.headers['Accept-Language'] = 'zh-CN,zh'
				c.params = {
					origin: o_name,
					destination: d_name
				}.merge(opts)
				c.params[:key] = key unless KEYS.empty?
				c.params[:departure_time] = Date.today.to_time.to_i + 10.hours if c.params[:mode] == 'transit'
			end
			response = conn.try(:get, '/maps/api/directions/json')
			if response.status == 301
				response = conn.try(:get, response.headers['location'])
			end
			JSONObject.new(response.body)
		end

		def self.staticmap *args
			case args.size
			when 1
				# Params: url
				url = args[0]
				res = nil
				Net::HTTP.start('maps.googleapis.com') do |http|
					res = http.get('/' + url.split('/')[3..-1].join('/'))
				end
				res.body
			when 2..4
				# Params: markers, path, accept, opts = {}
				markers = args[0]
				path = args[1]
				accept = args[2]
				opts = args[3] || {}
				conn = Conn.init(HOST) do |c|
					c.options[:proxy] = PROXY unless PROXY.blank?
					c.params = {
						size: '500x500',
						scale: 2,
						markers: ["size:small|", "size:small|color:blue|"],
						path: "color:0xff0000|weight:2|"
					}.merge(opts)
					c.params[:markers][0] += markers.first
					c.params[:markers][1] += markers.last
					c.params[:path] += "enc:#{path}"
				end
				case accept
				when :url
					"#{HOST}/maps/api/staticmap?#{conn.params.to_param}".gsub(/%5B%5D/, '')
				when :data
					response = conn.try(:get, '/maps/api/staticmap')
					response = GoogleMaps::Wraper.staticmap(response.headers['location']) if response.status == 301
					response.body
				else
					raise 'Accept Type Error'
				end
			else
				raise "wrong number of arguments (#{args.size} for 1..4)"				
			end
		end
	end

	class Serializers
		def as_json opts = {}
			attr_names = instance_variables.map{|v| v[1..-1]}

			if only = opts[:only]
				attr_names &= Array(only).map(&:to_s)
			elsif except = opts[:except]
				attr_names -= Array(except).map(&:to_s)
			end

			hash = attr_names.inject({}) do |res, n|
				res[n] = instance_variable_get("@#{n}")
				res[n] = res[n].as_json(opts) if res[n].respond_to?(:as_json)
				res
			end

			Array(opts[:methods]).each { |m| hash[m.to_s] = send(m) if respond_to?(m) }

			hash
		end
	end

	class RoundBounds < Struct.new(:location, :radius); end

	Geokit::Bounds.class_eval do
		def to_round_bounds size = 1
			mid = sw.midpoint_to(ne)
			case size
			when 1
				GoogleMaps::RoundBounds.new(mid, mid.distance_to(sw))
			when 4
				wn = Geokit::GeoLoc.normalize(sw.lat, ne.lng)
				es = Geokit::GeoLoc.normalize(ne.lat, sw.lng)
				[sw, wn, ne, es].map do |corner|
					sub_mid = mid.midpoint_to(corner)
					GoogleMaps::RoundBounds.new(sub_mid, sub_mid.distance_to(corner))
				end
			else
				raise ArgumentError.new("size must be `1' or `4'")
			end
		end
	end

	class Place < Serializers
		attr_accessor :name, :lat, :lng, :id, :place_id, :reference, :types, :vicinity

		def initialize json_object
			json_object.deep_symbolize_keys!
			@name      = json_object.name
			@lat       = json_object.geometry.location.lat
			@lng       = json_object.geometry.location.lng
			@id        = json_object.id
			@place_id  = json_object.place_id
			@reference = json_object.reference
			@types     = json_object.types
			@vicinity  = json_object.vicinity
		end

		def self.stations_in city_name
			loc = GeocodeApi.geocode(city_name, :google)
			sb = loc.suggested_bounds
			rbs = sb.to_round_bounds(4)
			rbs.map do |rb|
				params = {
					location: rb.location.ll,
					radius: (rb.radius * 1000).round(0),
					types: 'subway_station|transit_station|train_station'
				}
				data = GoogleMaps::Wraper.place(:nearbysearch, params)
				npt = data.next_page_token
				stations = data.results.map { |r| new(r) }
				while npt != nil
					sleep 1
					data = GoogleMaps::Wraper.place(:nearbysearch, pagetoken: npt)
					npt = data.next_page_token if data.status != "INVALID_REQUEST"
					stations += data.results.map { |r| new(r) }
				end
				pp "Found #{stations.size} stations."
				stations
			end.flatten
		end
	end

	class Direction < Serializers
		attr_accessor :origin, :destination, :options, :status, :routes

		def initialize origin = nil, destination = nil, opts = {}
			@origin = origin
			@destination = destination
			@options = opts
			@status = 'new'
		end

		def query
			result = GoogleMaps::Wraper.direction(@origin, @destination, @options.merge({mode: 'transit'}))
			result = GoogleMaps::Wraper.direction(@origin, @destination, @options) if result.status == 'ZERO_RESULTS'
			threads = []
			@routes = result.routes.map do |route|
				GoogleMaps::Route.parse_googlemaps_data(route, threads, preload: @options[:preload])
			end
			threads.each { |t| t.join }
			@status = result.status
		rescue Exception => e
			pp e
			pp e.backtrace
			@status = 'LocalSystemError'
		ensure
			return self
		end

		def self.parse_rome2rio_data data, opts = {}
			direction = new
			direction.status = 'OK'
			threads = []
			direction.routes = data.routes.map do |r|
				GoogleMaps::Route.parse_rome2rio_data(r, threads, opts)
			end
			threads.each { |t| t.join }
			direction
		end
	end

	class Route < Serializers
		attr_accessor :origin, :destination, :path, :markers, :distance, :duration, :staticmap_url, :steps, :name

		# def initialize json_object, threads, opts = {}
		# 	@origin = json_object.legs[0].start_address
		# 	@destination = json_object.legs[0].end_address
		# 	@distance = json_object.legs[0].distance.value / 1000.0
		# 	@duration = (json_object.legs[0].duration.value / 60.0).round(1)
		# 	@markers = json_object.legs[0].steps.map do |step|
		# 		step.start_location.as_json.values.join(',')
		# 	end << json_object.legs[0].steps.last.end_location.as_json.values.join(',')
		# 	@path = json_object.overview_polyline.points
		# 	escaped_path_size = CGI.escape(path).size
		# 	if escaped_path_size > 1800
		# 		points = Polylines::Decoder.decode_polyline(path)
		# 		ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
		# 		ziped_path = Polylines::Encoder.encode_points(ziped_points)
		# 	  @path = ziped_path
		# 	end
		# 	@steps = json_object.legs[0].steps.map.with_index(1) do |step, index|
		# 		GoogleMaps::Step.new(step, index, threads, opts)
		# 	end
		# 	threads << Thread.new do
		# 		@staticmap_url = GoogleMaps::Wraper.staticmap(@markers, @path, :url)
		# 		staticmap if opts[:preload] == "true"
		# 	end
		# end

		def as_json opts = {}
			super({methods: [:step_numbers, :overview]}.merge(opts))
		end

		def staticmap
			@staticmap = @staticmap || Base64.strict_encode64(GoogleMaps::Wraper.staticmap(@markers, @path, :data))
		end

		def step_numbers
			@steps.size
		end

		def overview
			@steps.inject([]) do |arr, step| 
				arr << step.overview if arr.last != step.overview
				arr
			end.compact.join(' => ')
		end

		def name
			@name ||= @steps.map(&:overview).compact.uniq.join(', ')
			@name
		end

		def self.parse_googlemaps_data json_object, threads, opts = {}
			route = new
			route.origin = json_object.legs[0].start_address
			route.destination = json_object.legs[0].end_address
			route.distance = json_object.legs[0].distance.value / 1000.0
			route.duration = (json_object.legs[0].duration.value / 60.0).round(1)
			route.markers = json_object.legs[0].steps.map do |step|
				step.start_location.as_json.values.join(',')
			end << json_object.legs[0].steps.last.end_location.as_json.values.join(',')
			route.path = json_object.overview_polyline.points
			escaped_path_size = CGI.escape(route.path).size
			if escaped_path_size > 1800
				points = Polylines::Decoder.decode_polyline(route.path)
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  route.path = ziped_path
			end
			route.steps = json_object.legs[0].steps.map.with_index(1) do |step, index|
				GoogleMaps::Step.parse_googlemaps_data(step, index, threads, opts)
			end
			threads << Thread.new do
				route.staticmap_url = GoogleMaps::Wraper.staticmap(route.markers, route.path, :url)
				route.staticmap if opts[:preload] == "true"
			end
			route.name
			route
		end

		def self.parse_rome2rio_data data, threads, opts = {}
			route = new
			route.name = data.name
			route.origin = data.segments.first.sName
			route.destination = data.segments.last.tName
			route.distance = data.distance
			route.duration = data.duration
			route.markers = data.segments.map do |seg|
				seg.sPos.as_json.values.join(',')
			end << data.segments.last.tPos.as_json.values.join(',')
			points = data.segments.inject([]) do |res, seg|
				res += Polylines::Decoder.decode_polyline(seg.path)
			end
			pp points
			path = Polylines::Encoder.encode_points(points)
			escaped_path_size = CGI.escape(path).size
			if escaped_path_size > 1800
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  route.path = ziped_path
			else
				route.path = path
			end
			route.steps = data.segments.map.with_index(1) do |seg, i|
				GoogleMaps::Step.parse_rome2rio_data(seg, i, threads, opts)
			end
			threads << Thread.new do
				route.staticmap_url = GoogleMaps::Wraper.staticmap(route.markers, route.path, :url)
				route.staticmap if opts[:preload] == "true"
			end
			route
		end
	end

	class Step < Serializers
		attr_accessor :step_number, :distance, :duration ,:start_location, :end_location, :path, :transit_details, :html_instructions, :travel_mode, :staticmap_url

		def self.parse_googlemaps_data json_object, number, threads, opts = {}
			step = new
			step.step_number = number
			step.distance = json_object.distance.value / 1000.0
			step.duration = (json_object.duration.value / 60.0).round(1)
			step.start_location = json_object.start_location.as_json.values.join(',')
			step.end_location = json_object.end_location.as_json.values.join(',')
			step.path = json_object.polyline.points
			escaped_path_size = CGI.escape(step.path).size
			if escaped_path_size > 1800
				points = Polylines::Decoder.decode_polyline(step.path)
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  step.path = ziped_path
			end
			step.transit_details = json_object.transit_details.instance_eval do
				if self
					{
						departure: departure_stop.name,
						arrival: arrival_stop.name,
						headsign: headsign,
						name: [line.name, line.short_name].compact.join(' '),
						vehicle: line.vehicle.type,
						icon: line.vehicle.icon,
						stops: num_stops
					}
				else
					{}
				end
			end
			step.html_instructions = json_object.steps.to_a.inject([json_object.html_instructions]){|res, s| res << s.html_instructions }.compact
			step.travel_mode = json_object.travel_mode
			map_size = case step.distance
			when 0...1
				'200x200'
			else
				'500x500'
			end
			threads << Thread.new do
				step.staticmap_url = GoogleMaps::Wraper.staticmap([step.start_location, step.end_location], step.path, :url, size: map_size)
				step.staticmap if opts[:preload] == "true"
			end
			step
		end

		def self.parse_rome2rio_data data, number, threads, opts = {}
			step = new
			step.step_number = number
			step.distance = data.distance
			step.duration = data.duration
			step.start_location = data.sPos.as_json.values.join(',')
			step.end_location = data.tPos.as_json.values.join(',')
			step.path = data.path
			escaped_path_size = CGI.escape(step.path).size
			if escaped_path_size > 1800
				points = Polylines::Decoder.decode_polyline(step.path)
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  step.path = ziped_path
			end
			step.transit_details = begin
				data.itineraries.first.legs.first.hops.first.instance_eval do
					{
						departure: sName,
						arrival: tName,
						name: lines.first.name,
						vehicle: lines.first.vehicle
					}
				end
			rescue Exception => e
				{}
			end
			step.travel_mode = data.kind
			map_size = case step.distance
			when 0...1
				'200x200'
			else
				'500x500'
			end
			threads << Thread.new do
				step.staticmap_url = GoogleMaps::Wraper.staticmap([step.start_location, step.end_location], step.path, :url, size: map_size)
				step.staticmap if opts[:preload] == "true"
			end
			step
		end

		def as_json *args
			json = super
			json.delete('transit_details') if json['transit_details'] == {}
			json
		end

		def staticmap
			@staticmap = @staticmap || Base64.strict_encode64(GoogleMaps::Wraper.staticmap([@start_location, @end_location], @path, :data, size: @map_size))
		end

		def overview
			case @travel_mode
			when 'WALKING', 'walk'
				if @html_instructions == nil || @html_instructions.size > 1
					'步行'
				else
					nil
				end
			when 'DRIVING', 'car'
				'驾车'
			when 'TRANSIT', 'bus', 'train'
				@transit_details[:name]
			end
		end

		def instructions
			@html_instructions.map do |html_inst|
				html_inst.gsub(/\<.*?\>/, '')
			end
		end
	end
end
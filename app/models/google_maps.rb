# encoding: utf-8

module GoogleMaps
	UrlThresholdBase = 0.0007 / 2000

	class Wraper
		HOST = 'http://maps.googleapis.com'
		PROXY = ''

		def self.direction o_name, d_name, opts = {}
			conn = Conn.init(HOST) do |c|
				c.options[:proxy] = PROXY unless PROXY.blank?
				c.headers['Accept-Language'] = 'zh-CN,zh'
				c.params = {
					origin: o_name,
					destination: d_name,
					sensor: false
				}.merge(opts)
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

	class Direction < Serializers
		attr_reader :origin, :destination, :options, :status, :routes

		def initialize origin, destination, opts = {}
			@origin = origin
			@destination = destination
			@options = opts
			begin
				result = GoogleMaps::Wraper.direction(@origin, @destination, @options.merge({mode: 'transit'}))
				result = GoogleMaps::Wraper.direction(@origin, @destination, @options) if result.status == 'ZERO_RESULTS'
				threads = []
				@routes = result.routes.map do |route|
					GoogleMaps::Route.new(route, threads, preload: opts[:preload])
				end
				threads.each { |t| t.join }
				@status = result.status
			rescue Exception => e
				pp e
				pp e.backtrace
				@status = 'LocalSystemError'
			end
		end
	end

	class Route < Serializers
		attr_reader :origin, :destination, :path, :markers, :distance, :duration, :staticmap_url, :steps

		def initialize json_object, threads, opts = {}
			@origin = json_object.legs[0].start_address
			@destination = json_object.legs[0].end_address
			@distance = json_object.legs[0].distance.value / 1000.0
			@duration = (json_object.legs[0].duration.value / 60.0).round(1)
			@markers = json_object.legs[0].steps.map do |step|
				step.start_location.as_json.values.join(',')
			end << json_object.legs[0].steps.last.end_location.as_json.values.join(',')
			@path = json_object.overview_polyline.points
			escaped_path_size = CGI.escape(path).size
			if escaped_path_size > 1800
				points = Polylines::Decoder.decode_polyline(path)
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  @path = ziped_path
			end
			@steps = json_object.legs[0].steps.map.with_index(1) do |step, index|
				GoogleMaps::Step.new(step, index, threads, opts)
			end
			threads << Thread.new do
				@staticmap_url = GoogleMaps::Wraper.staticmap(@markers, @path, :url)
				staticmap if opts[:preload] == "true"
			end
		end

		def as_json opts = {}
			super({methods: [:step_numbers, :overview, :name]}.merge(opts))
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
			@steps.map(&:overview).compact.uniq.join(', ')
		end
	end

	class Step < Serializers
		attr_reader :step_number, :distance, :duration ,:start_location, :end_location, :path, :transit_details, :html_instructions, :travel_mode, :staticmap_url

		def initialize json_object, number, threads, opts = {}
			@step_number = number
			@distance = json_object.distance.value / 1000.0
			@duration = (json_object.duration.value / 60.0).round(1)
			@start_location = json_object.start_location.as_json.values.join(',')
			@end_location = json_object.end_location.as_json.values.join(',')
			@path = json_object.polyline.points
			escaped_path_size = CGI.escape(path).size
			if escaped_path_size > 1800
				points = Polylines::Decoder.decode_polyline(path)
				ziped_points = DouglasPeucker::LineSimplifier.new(points).threshold(escaped_path_size * GoogleMaps::UrlThresholdBase).points
				ziped_path = Polylines::Encoder.encode_points(ziped_points)
			  @path = ziped_path
			end
			@transit_details = json_object.transit_details.instance_eval do
				if self
					{
						departure: departure_stop.name,
						arrival: arrival_stop.name,
						headsign: headsign,
						name: [line.name, line.short_name].compact.join(' '),
						vehicle: line.vehicle.type,
						stops: num_stops
					}
				else
					{}
				end
			end
			@html_instructions = json_object.steps.to_a.inject([json_object.html_instructions]){|res, s| res << s.html_instructions }.compact
			@travel_mode = json_object.travel_mode
			@map_size = case distance
			when 0...1
				'200x200'
			else
				'500x500'
			end
			threads << Thread.new do
				@staticmap_url = GoogleMaps::Wraper.staticmap([@start_location, @end_location], @path, :url, size: @map_size)
				staticmap if opts[:preload] == "true"
			end
		end

		def staticmap
			@staticmap = @staticmap || Base64.strict_encode64(GoogleMaps::Wraper.staticmap([@start_location, @end_location], @path, :data, size: @map_size))
		end

		def overview
			case @travel_mode
			when 'WALKING'
				if @html_instructions.size > 1
					'步行'
				else
					nil
				end
			when 'DRIVING'
				'驾车'
			when 'TRANSIT'
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
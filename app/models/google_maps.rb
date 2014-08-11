# encoding: utf-8

module GoogleMaps
	class Wraper
		HOST = 'http://maps.googleapis.com'
		PROXY = 'http://127.0.0.1:8087'

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

		def self.staticmap markers, path, accept = :url, opts = {}
			conn = Conn.init(HOST) do |c|
				c.options[:proxy] = PROXY unless PROXY.blank?
				c.params = {
					size: '500x500',
					scale: 2,
					markers: "size:small|",
					path: "color:0xff0000|weight:2|"
				}.merge(opts)
				c.params[:markers] += "#{markers.first}|#{markers.last}"
				c.params[:path] += "enc:#{path}"
			end
			response = conn.try(:get, '/maps/api/staticmap')
			case accept
			when :url
				if response.status == 301
					response.headers['location']
				else
					"#{HOST}/maps/api/staticmap?#{conn.params.to_param}"
				end
			when :data
				response = conn.try(:get, response.headers['location']) if response.status == 301
				response.body
			else
				raise 'Accept Type Error'
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
		attr_accessor :origin, :destination, :options, :status, :routes

		def initialize origin, destination, opts = {}
			@origin = origin
			@destination = destination
			@options = opts
			begin
				result = GoogleMaps::Wraper.direction(@origin, @destination, @options.merge({mode: 'transit'}))
				result = GoogleMaps::Wraper.direction(@origin, @destination, @options) if result.status == 'ZERO_RESULTS'
				@routes = result.routes.map do |route|
					GoogleMaps::Route.new(route)
				end
				@status = result.status
			rescue Exception => e
				p e
				p e.backtrace
				@status = 'LocalSystemError'
			end
		end
	end

	class Route < Serializers
		attr_reader :origin, :destination, :path, :markers, :distance, :duration, :staticmap_url, :steps

		def initialize json_object
			@origin = json_object.legs[0].start_address
			@destination = json_object.legs[0].end_address
			@distance = json_object.legs[0].distance.value
			@duration = json_object.legs[0].duration.value
			@markers = json_object.legs[0].steps.map do |step|
				step.start_location.as_json.values.join(',')
			end << json_object.legs[0].steps.last.end_location.as_json.values.join(',')
			@path = json_object.overview_polyline.points
			@steps = json_object.legs[0].steps.map.with_index(1) do |step, index|
				GoogleMaps::Step.new(step, index)
			end
			@staticmap_url = GoogleMaps::Wraper.staticmap(@markers, @path, :url)
		end

		def as_json opts = {}
			super({methods: [:step_numbers, :overview], except: :staticmap}.merge(opts))
		end

		def staticmap
			@staticmap = @staticmap || Base64.strict_encode64(GoogleMaps::Wraper.staticmap(@markers, @path, :data))
		end

		def step_numbers
			@steps.size
		end

		def overview
			@steps.map{|step| step.overview}.compact.join(' => ')
		end
	end

	class Step < Serializers
		attr_reader :step_number, :distance, :duration ,:start_location, :end_location, :path, :transit_details, :html_instructions, :travel_mode, :staticmap_url

		def initialize json_object, number
			@step_number = number
			@distance = json_object.distance.value
			@duration = json_object.duration.value
			@start_location = json_object.start_location.as_json.values.join(',')
			@end_location = json_object.end_location.as_json.values.join(',')
			@path = json_object.polyline.points
			@transit_details = json_object.transit_details.instance_eval do
				if self
					{
						departure: departure_stop.name,
						arrival: arrival_stop.name,
						headsign: headsign,
						name: line.short_name,
						vehicle: line.vehicle.type 
					}
				else
					nil
				end
			end
			@html_instructions = json_object.steps.to_a.inject([json_object.html_instructions]){|res, s| res << s.html_instructions }.compact
			@travel_mode = json_object.travel_mode
			@staticmap_url = GoogleMaps::Wraper.staticmap([@start_location, @end_location], @path, :url, size: '200x200')
		end

		def as_json opts = {}
			super({except: :staticmap}.merge(opts))
		end

		def staticmap
			@staticmap = @staticmap || Base64.strict_encode64(GoogleMaps::Wraper.staticmap([@start_location, @end_location], @path, :data, size: '200x200'))
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
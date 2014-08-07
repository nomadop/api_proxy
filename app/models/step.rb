class Step < ActiveRecord::Base
	after_initialize :init_serialize

	dragonfly_accessor :map
	serialize :transit_details, Hash
	serialize :html_instructions, Array
	belongs_to :routes
	default_scope { order(:step_number) }

	def self.create_by_json json_object, number
		Step.create(
			step_number: number,
			distance: json_object.distance.value,
			duration: json_object.duration.value,
			start_location: json_object.start_location.as_json.values.join(','),
			end_location: json_object.end_location.as_json.values.join(','),
			path: json_object.polyline.points,
			transit_details: json_object.transit_details.instance_eval do
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
			end,
			html_instructions: json_object.steps.to_a.inject([json_object.html_instructions]){|res, s| res << s.html_instructions }.compact,
			travel_mode: json_object.travel_mode
		)
	end

	def map
		return super if super != nil
		self.map = get_staticmap
		self.save
		super
	end

	def instructions
		html_instructions.map do |html_inst|
			html_inst.gsub(/\<.*?\>/, '')
		end
	end

	private
		def init_serialize
			self.transit_details ||= {}
			self.html_instructions ||= []
		end

		def get_staticmap
			self.map = GoogleMaps.staticmap([start_location, end_location], path, :data, size: '200x200')
		end
end

class Route < ActiveRecord::Base
	after_initialize :init_markers

	dragonfly_accessor :map
	serialize :markers, Array
	belongs_to :direction
	has_many :steps, dependent: :destroy

	def self.create_by_json json_object
		Route.create(
			origin: json_object.legs[0].start_address,
			destination: json_object.legs[0].end_address,
			markers: json_object.legs[0].steps.map do |step|
				step.start_location.as_json.values.join(',')
			end << json_object.legs[0].steps.last.end_location.as_json.values.join(','),
			path: json_object.overview_polyline.points,
			steps: json_object.legs[0].steps.map.with_index(1) do |step, index|
				Step.create_by_json(step, index)
			end
		)
	end

	def travel_modes
		steps.map(&:travel_mode).uniq
	end

	def map
		return super if super != nil
		self.map = get_staticmap
		self.save
		super
	end

	private
		def init_markers
			self.markers ||= []
		end

		def get_staticmap
			self.map = GoogleMaps.staticmap([markers.first, markers.last], path, :data)
		end
end

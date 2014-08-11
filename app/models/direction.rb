class Direction < ActiveRecord::Base
	after_initialize :init_serialize
	before_update :change_status

	store :options, accessors: [:sensor, :mode, :waypoints, :alternatives, :avoid, :units, :region, :departure_time, :arrival_time]
	has_many :routes, dependent: :destroy

	def search
		return false if status == 'Searching'
		self.update(status: 'Searching')
		result = GoogleMaps::Wraper.direction(origin, destination, options)
		result = GoogleMaps::Wraper.direction(origin, destination, options.merge({mode: 'driving'})) if result.status == 'ZERO_RESULTS'
		self.routes.destroy_all
		result.routes.each do |route|
			self.routes.create_by_json(route)
		end
		self.update(status: result.status)
	rescue Exception => e
		self.update(status: 'LocalSystemError')		
	end

	private
		def init_serialize
			self.options ||= {}
		end

		def change_status
			self.status = 'Modified'
		end
end

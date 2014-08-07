class Direction < ActiveRecord::Base
	after_initialize :init_serialize

	store :options, accessors: [:sensor, :mode, :waypoints, :alternatives, :avoid, :units, :region, :departure_time, :arrival_time]
	has_many :routes, dependent: :destroy

	def search
		return false if status == 'Searching'
		self.update(status: 'Searching')
		result = GoogleMaps.direction(origin, destination, options)
		result.routes.each do |route|
			routes.create_by_json(route)
		end
		self.update(status: result.status)
	rescue Exception => e
		self.update(status: 'LocalSystemError')		
	end

	private
		def init_serialize
			self.options ||= {}
		end
end

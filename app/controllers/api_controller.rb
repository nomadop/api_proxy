class ApiController < ApplicationController
  # protect_from_forgery :only  => []

	def direction
		response = {}
		begin
			if params[:o] && params[:d]
				opts = params.clone.as_json
				opts.delete(:o)
				opts.delete(:d)
				direction = GoogleMaps::Direction.new(params[:o], params[:d], opts)
				data = if params[:map] == 'true'
					direction.as_json(methods: :staticmap)
				else
					direction.as_json
				end
				response = { status: 200, data: data }
			else
				response = { status: 204, data: 'Wrong Parameters' }
			end
		rescue Exception => e
			p e
			p e.backtrace
			response = { status: 500, data: {error: e.inspect, backtrace: e.backtrace} }
		end
		render json: JSON.generate(response)
	end
end
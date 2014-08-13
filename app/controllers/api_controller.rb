class ApiController < ApplicationController
  # protect_from_forgery :only  => []
  require 'pp'

	def direction
		@response = {}
		begin
			if params[:o] && params[:d]
				opts = params.as_json

				case params[:p]
				when 'rome2rio'
					res = Rome2rio::Connection.new.search(oName: params[:o], dName: params[:d], key: 'INyVvCSX')
					res.routes.map(&:segments).flatten.each do |seg|
						seg.class.send(:attr_reader, :staticmap_url) unless seg.respond_to?(:staticmap_url)
						map_size = case seg.distance
						when 0...1
							'200x200'
						else
							'500x500'
						end
						seg.instance_variable_set(:@staticmap_url, GoogleMaps::Wraper.staticmap([seg.sPos.to_s, seg.tPos.to_s], seg.path, :url, size: map_size)).gsub(/%5B%5D/, '')
					end
					data = { 'origin' => params[:o], 'destination' => params[:d], 'routes' => res.routes.select{|r| r.name != 'Walk' && r.name != 'Taxi'}.as_json, 'provider' => 'Rome2rio' }
				else
					direction = GoogleMaps::Direction.new(params[:o], params[:d], opts)
					data = if params[:map] == 'true'
						direction.as_json(methods: [:step_numbers, :overview, :staticmap])
					else
						direction.as_json
					end.merge({'provider' => 'GoogleMaps'})
				end

				@response = { status: 200, data: data }
			else
				@response = { status: 204, data: 'Wrong Parameters' }
			end
		rescue Exception => e
			pp e
			pp e.backtrace
			@response = { status: 500, data: {error: e.inspect, backtrace: e.backtrace} }
		end

		respond_to do |format|
      format.html
      format.json { render json: JSON.generate(@response) }
    end
	end
end
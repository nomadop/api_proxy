class GeocodeController < ApplicationController
	
	def latlng
		loc = GeocodeApi.geocode(params[:address], params[:api])
		render json: {lat:loc.lat, lng:loc.lng}
	end

end
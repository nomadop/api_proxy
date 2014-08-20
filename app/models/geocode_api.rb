class GeocodeApi
	# ApiKeys
	ApiKeys = {
		google: 'AIzaSyAXngIRBBzOVy_k9OIjEn9rW33FPCEJ6C0',
		map_quest: 'Fmjtd%7Cluur206y2q%2Crw%3Do5-9ay2dy',
		bing: 'Ao9yUqipvyK9Gyt1jZEiolDPDNQ4evUSSKlvUN7t0rx0iiD-u9uMNeHsojrRyNVY',
		geonames: 'nomadop'
	}
	RegApis = [:google, :map_quest, :bing, :geonames]
	
	def self.geocode address, api, opts = {}
		raise 'No such api' unless RegApis.include?(api.to_sym)
		geocoder = Geokit::Geocoders.const_get("#{api.to_s.camelize}Geocoder")
		geocoder.key = GeocodeApi::ApiKeys[api.to_sym] if geocoder.respond_to?(:key)
		geocoder.premium = false if geocoder.respond_to?(:premium)
		args = [address]
		args << opts if api.to_sym == :google
		geocoder.geocode(*args)
	end

end
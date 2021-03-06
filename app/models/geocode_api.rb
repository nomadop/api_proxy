class GeocodeApi
	# ApiKeys
	ApiKeys = {
		map_quest: 'Fmjtd%7Cluur206y2q%2Crw%3Do5-9ay2dy',
		bing: 'Ao9yUqipvyK9Gyt1jZEiolDPDNQ4evUSSKlvUN7t0rx0iiD-u9uMNeHsojrRyNVY',
		geonames: 'nomadop'
	}
	RegApis = [:google, :map_quest, :bing, :geonames, :multi]
	
	def self.geocode address, api, opts = {}
		raise 'No such api' unless RegApis.include?(api.to_sym)
		geocoder = Geokit::Geocoders.const_get("#{api.to_s.camelize}Geocoder")
		geocoder.key = GeocodeApi::ApiKeys[api.to_sym] if geocoder.respond_to?(:key)
		geocoder.premium = false if geocoder.respond_to?(:premium)
		args = [address]
		if api.to_sym == :google
			geocoder.api_key = GoogleApis.key
			args << opts
		end
		geocoder.geocode(*args)
	end

end